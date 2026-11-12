-- =====================================================================
-- Bloome — 02_funcoes.sql
--
-- Papel no sistema: transformar as regras de negócio (ADR-011/ADR-012)
-- em funções e triggers executados pelo próprio PostgreSQL. É a camada
-- que garante que estoque, pagamento, cancelamento, totais e webhook
-- não dependam da boa vontade do backend.
--
-- Rode DEPOIS de `01_schema.sql`. O arquivo é idempotente: usa
-- `create or replace function` e `drop trigger if exists` antes de
-- recriar cada trigger. Nenhum DROP de tabela, schema ou função de
-- negócio é executado.
--
-- Tipagem: dinheiro NUMERIC(10,2); insumos NUMERIC(12,3); datas TIMESTAMPTZ.
-- Locking: sempre o pedido primeiro; depois os insumos em ordem crescente
-- de id_insumos (evita deadlock entre dois pedidos disputando insumo).
-- =====================================================================

begin;

-- =====================================================================
-- 1. atualizado_em genérico
-- =====================================================================

-- EC-35: toda alteração carimba a hora com TIMESTAMPTZ.
create or replace function bloome.fn_atualizado_em()
returns trigger
language plpgsql
set search_path = bloome, pg_temp
as $$
begin
    new.atualizado_em := now();
    return new;
end;
$$;

-- =====================================================================
-- 2. Custo da receita de uma variação
-- =====================================================================

-- EC-02/EC-38: custo é derivado da receita (insumo x quantidade),
-- nunca digitado. Usado no checkout para gravar o snapshot.
create or replace function bloome.calcular_custo_variacao(p_id_variacao integer)
returns numeric(10,2)
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_custo numeric(10,2);
begin
    select coalesce(sum(cv.quantidade * i.valor_unitario), 0)::numeric(10,2)
      into v_custo
      from bloome.composicao_variacoes cv
      join bloome.insumos i on i.id_insumos = cv.id_insumos
     where cv.id_variacao = p_id_variacao;

    return v_custo;
end;
$$;

-- =====================================================================
-- 3. Pré-check / recheck agregado de estoque
-- =====================================================================

-- EC-04/EC-08: soma o consumo de todos os itens por insumo.
-- Variação sem nenhuma linha de receita bloqueia a venda (P0002), pois
-- sem receita não há como saber o que baixar.
create or replace function bloome.verificar_estoque_pedido(p_id_pedidos integer)
returns table (
    id_insumos integer,
    nome text,
    necessario numeric,
    disponivel numeric,
    suficiente boolean
)
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_id_variacao integer;
begin
    -- EC-08: uma única variação sem receita já invalida o pedido.
    select ip.id_variacao
      into v_id_variacao
      from bloome.itens_pedidos ip
     where ip.id_pedidos = p_id_pedidos
       and not exists (
           select 1
             from bloome.composicao_variacoes cv
            where cv.id_variacao = ip.id_variacao
       )
     order by ip.id_variacao
     limit 1;

    if v_id_variacao is not null then
        raise exception using
            errcode = 'P0002',
            message = 'produto_sem_receita',
            detail  = format('id_variacao=%s', v_id_variacao);
    end if;

    -- EC-04: consumo agregado por insumo, comparado ao saldo atual.
    return query
    select i.id_insumos,
           i.nome,
           sum(cv.quantidade * ip.quantidade)::numeric as necessario,
           i.quantidade_estoque::numeric             as disponivel,
           (i.quantidade_estoque >= sum(cv.quantidade * ip.quantidade)) as suficiente
      from bloome.itens_pedidos ip
      join bloome.composicao_variacoes cv on cv.id_variacao = ip.id_variacao
      join bloome.insumos i             on i.id_insumos  = cv.id_insumos
     where ip.id_pedidos = p_id_pedidos
     group by i.id_insumos, i.nome, i.quantidade_estoque
     order by i.id_insumos;
end;
$$;

-- =====================================================================
-- 4. Baixa agregada de estoque
-- =====================================================================

-- EC-01/EC-03/EC-40/EC-41: baixa SÓ quando chamada (no pagamento),
-- de uma vez, em um único UPDATE agregado. Trava os insumos em ordem
-- crescente de id_insumos para dois pedidos não se travarem em ciclo.
-- A checagem é feita ANTES do UPDATE para devolver P0003 em vez do
-- erro genérico de CHECK (23514) da coluna quantidade_estoque.
create or replace function bloome.baixar_estoque_pedido(p_id_pedidos integer)
returns void
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_id_variacao integer;
    v_rec record;
    v_baixado boolean;
begin
    -- Chamada direta em pedido inexistente ou já baixado é erro de uso.
    select p.estoque_baixado
      into v_baixado
      from bloome.pedidos p
     where p.id_pedidos = p_id_pedidos
       for update;

    if not found then
        raise exception using
            errcode = 'P0002',
            message = 'pedido_inexistente',
            detail  = format('id_pedidos=%s', p_id_pedidos);
    end if;

    if v_baixado then
        raise exception using
            errcode = 'P0001',
            message = 'estoque_ja_baixado',
            detail  = format('id_pedidos=%s', p_id_pedidos);
    end if;

    -- EC-08: defesa extra para chamada direta (o fluxo normal já passou
    -- por verificar_estoque_pedido).
    select ip.id_variacao
      into v_id_variacao
      from bloome.itens_pedidos ip
     where ip.id_pedidos = p_id_pedidos
       and not exists (
           select 1
             from bloome.composicao_variacoes cv
            where cv.id_variacao = ip.id_variacao
       )
     order by ip.id_variacao
     limit 1;

    if v_id_variacao is not null then
        raise exception using
            errcode = 'P0002',
            message = 'produto_sem_receita',
            detail  = format('id_variacao=%s', v_id_variacao);
    end if;

    -- EC-41: trava os insumos envolvidos em ordem crescente.
    perform 1
      from bloome.insumos i
     where i.id_insumos in (
         select cv.id_insumos
           from bloome.itens_pedidos ip
           join bloome.composicao_variacoes cv on cv.id_variacao = ip.id_variacao
          where ip.id_pedidos = p_id_pedidos
     )
     order by i.id_insumos
     for update;

    -- EC-40: recheca o saldo já com os locks na mão.
    for v_rec in
        select i.id_insumos,
               i.nome,
               i.quantidade_estoque,
               c.qtd
          from bloome.insumos i
          join (
              select cv.id_insumos,
                     sum(cv.quantidade * ip.quantidade) as qtd
                from bloome.itens_pedidos ip
                join bloome.composicao_variacoes cv on cv.id_variacao = ip.id_variacao
               where ip.id_pedidos = p_id_pedidos
               group by cv.id_insumos
          ) c on c.id_insumos = i.id_insumos
         order by i.id_insumos
    loop
        if v_rec.quantidade_estoque < v_rec.qtd then
            raise exception using
                errcode = 'P0003',
                message = 'estoque_insuficiente',
                detail  = format(
                    'id_insumos=%s nome=%s necessario=%s disponivel=%s',
                    v_rec.id_insumos, v_rec.nome, v_rec.qtd, v_rec.quantidade_estoque
                );
        end if;
    end loop;

    -- EC-01/EC-03: baixa agregada, um único UPDATE.
    update bloome.insumos i
       set quantidade_estoque = i.quantidade_estoque - c.qtd
      from (
          select cv.id_insumos,
                 sum(cv.quantidade * ip.quantidade) as qtd
            from bloome.itens_pedidos ip
            join bloome.composicao_variacoes cv on cv.id_variacao = ip.id_variacao
           where ip.id_pedidos = p_id_pedidos
           group by cv.id_insumos
      ) c
     where i.id_insumos = c.id_insumos;

    -- Registra exatamente o que foi baixado. A devolução usa este snapshot,
    -- não a receita atual (que pode mudar depois do pagamento).
    update bloome.pedidos p
       set consumo_snapshot = coalesce((
               select jsonb_object_agg(c.id_insumos::text, c.qtd)
                 from (
                     select cv.id_insumos,
                            sum(cv.quantidade * ip.quantidade) as qtd
                       from bloome.itens_pedidos ip
                       join bloome.composicao_variacoes cv on cv.id_variacao = ip.id_variacao
                      where ip.id_pedidos = p_id_pedidos
                      group by cv.id_insumos
                 ) c
           ), '{}'::jsonb)
     where p.id_pedidos = p_id_pedidos;
end;
$$;

-- =====================================================================
-- 5. Devolução de estoque no cancelamento
-- =====================================================================

-- EC-06: devolve uma única vez, só se estoque_baixado = true, e zera a
-- flag. A segunda chamada devolve false.
--
-- IMPORTANTE: ck_pedidos_producao_estoque exige estoque_baixado = true
-- enquanto o status estiver em pago/em_producao/pronto_para_retirada/
-- enviado/entregue. Por isso a devolução só pode zerar a flag depois
-- que o pedido já está 'cancelado'. A função exige esse estado e
-- cancelar_pedido() muda o status ANTES de chamá-la.
create or replace function bloome.devolver_estoque_pedido(p_id_pedidos integer)
returns boolean
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_status text;
    v_baixado boolean;
    v_snapshot jsonb;
begin
    -- Lock anti-deadlock: pedido primeiro.
    select p.status, p.estoque_baixado, p.consumo_snapshot
      into v_status, v_baixado, v_snapshot
      from bloome.pedidos p
     where p.id_pedidos = p_id_pedidos
       for update;

    if not found then
        return false;
    end if;

    -- EC-06: nada a devolver (ou devolução já feita).
    if not v_baixado then
        return false;
    end if;

    -- EC-05/EC-43/EC-44: ver a nota acima sobre o CHECK do schema.
    if v_status <> 'cancelado' then
        raise exception using
            errcode = 'P0001',
            message = 'cancelamento_nao_permitido',
            detail  = format('status=%s', v_status);
    end if;

    -- EC-41: devolve exatamente o que foi baixado. Se o pedido é antigo e
    -- não tem snapshot, cai na receita atual (fallback).
    if v_snapshot is not null then
        perform 1
          from bloome.insumos i
         where i.id_insumos in (
             select (e.key)::integer
               from jsonb_each_text(v_snapshot) e
         )
         order by i.id_insumos
         for update;

        update bloome.insumos i
           set quantidade_estoque = i.quantidade_estoque + (e.value)::numeric
          from jsonb_each_text(v_snapshot) e
         where i.id_insumos = (e.key)::integer;
    else
        perform 1
          from bloome.insumos i
         where i.id_insumos in (
             select cv.id_insumos
               from bloome.itens_pedidos ip
               join bloome.composicao_variacoes cv on cv.id_variacao = ip.id_variacao
              where ip.id_pedidos = p_id_pedidos
         )
         order by i.id_insumos
         for update;

        update bloome.insumos i
           set quantidade_estoque = i.quantidade_estoque + c.qtd
          from (
              select cv.id_insumos,
                     sum(cv.quantidade * ip.quantidade) as qtd
                from bloome.itens_pedidos ip
                join bloome.composicao_variacoes cv on cv.id_variacao = ip.id_variacao
               where ip.id_pedidos = p_id_pedidos
               group by cv.id_insumos
          ) c
         where i.id_insumos = c.id_insumos;
    end if;

    update bloome.pedidos p
       set estoque_baixado = false
     where p.id_pedidos = p_id_pedidos;

    return true;
end;
$$;

-- =====================================================================
-- 6. Confirmação de pagamento (webhook)
-- =====================================================================

-- EC-03/EC-04/EC-05/EC-23: idempotente. Trava o pedido, recheca o
-- estoque, baixa tudo ou marca pago_sem_estoque. Qualquer exceção
-- (inclusive produto_sem_receita ou estoque_insuficiente em corrida)
-- desfaz a baixa porque tudo roda na mesma transação.
create or replace function bloome.confirmar_pagamento(
    p_id_pedidos integer,
    p_gateway text,
    p_evento_id text
)
returns text
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_status text;
    v_baixado boolean;
    v_suficiente boolean := true;
    v_resultado text;
    v_rec record;
begin
    -- Lock anti-deadlock: pedido primeiro.
    select p.status, p.estoque_baixado
      into v_status, v_baixado
      from bloome.pedidos p
     where p.id_pedidos = p_id_pedidos
       for update;

    if not found then
        raise exception using
            errcode = 'P0002',
            message = 'pedido_inexistente',
            detail  = format('id_pedidos=%s', p_id_pedidos);
    end if;

    -- EC-23: webhook repetido. O status já é de pedido pago e o estoque
    -- já foi baixado: não baixa de novo.
    if v_status in ('pago', 'em_producao', 'pronto_para_retirada', 'enviado', 'entregue')
       and v_baixado then
        return 'ja_processado';
    end if;

    -- EC-33: fora de aguardando_pagamento e pago_sem_estoque não há
    -- transição legítima para pagamento.
    if v_status not in ('aguardando_pagamento', 'pago_sem_estoque') then
        raise exception using
            errcode = 'P0001',
            message = 'transicao_invalida',
            detail  = format('status=%s', v_status);
    end if;

    -- Pedido vazio não vira pago: sem item não há o que produzir nem baixar.
    if not exists (
        select 1
          from bloome.itens_pedidos ip
         where ip.id_pedidos = p_id_pedidos
    ) then
        raise exception using
            errcode = 'P0002',
            message = 'pedido_sem_itens',
            detail  = format('id_pedidos=%s', p_id_pedidos);
    end if;

    -- EC-04/EC-08: recheca no pagamento. Pode levantar produto_sem_receita.
    for v_rec in
        select *
          from bloome.verificar_estoque_pedido(p_id_pedidos)
    loop
        if not v_rec.suficiente then
            v_suficiente := false;
            exit;
        end if;
    end loop;

    if not v_suficiente then
        -- EC-05: acabou entre o checkout e o pagamento; sem baixa.
        update bloome.pedidos p
           set status = 'pago_sem_estoque',
               estoque_baixado = false
         where p.id_pedidos = p_id_pedidos;

        v_resultado := 'pago_sem_estoque';
    else
        -- EC-01/EC-03: baixa agregada e só então marca pago.
        perform bloome.baixar_estoque_pedido(p_id_pedidos);

        update bloome.pedidos p
           set status = 'pago',
               estoque_baixado = true
         where p.id_pedidos = p_id_pedidos;

        v_resultado := 'pago';
    end if;

    -- EC-23/EC-25: atualiza o evento do webhook, se ele foi informado.
    -- Evento inexistente não é erro (pode ter sido criado fora do fluxo
    -- normal ou o pedido pode ter sido confirmado manualmente).
    if p_gateway is not null and p_evento_id is not null then
        update bloome.eventos_pagamento e
           set id_pedidos = p_id_pedidos,
               status_evento = 'processado',
               processado_em = now(),
               tentativas = e.tentativas + 1
         where e.gateway = p_gateway
           and e.evento_id = p_evento_id;
    end if;

    return v_resultado;
end;
$$;

-- =====================================================================
-- 7. Cancelamento
-- =====================================================================

-- EC-06/EC-07/EC-42: cancela só até pago/pago_sem_estoque. Devolve o
-- insumo uma única vez (se houve baixa) e registra o motivo. Reembolso
-- continua manual: reembolsado_em/reembolso_valor NÃO são preenchidos.
create or replace function bloome.cancelar_pedido(
    p_id_pedidos integer,
    p_motivo text
)
returns text
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_status text;
    v_baixado boolean;
begin
    -- Lock anti-deadlock: pedido primeiro.
    select p.status, p.estoque_baixado
      into v_status, v_baixado
      from bloome.pedidos p
     where p.id_pedidos = p_id_pedidos
       for update;

    if not found then
        raise exception using
            errcode = 'P0002',
            message = 'pedido_inexistente',
            detail  = format('id_pedidos=%s', p_id_pedidos);
    end if;

    -- EC-07: a partir de em_producao o cancelamento é proibido.
    if v_status not in ('aguardando_pagamento', 'pago', 'pago_sem_estoque') then
        raise exception using
            errcode = 'P0001',
            message = 'transicao_invalida',
            detail  = format('%s -> cancelado', v_status);
    end if;

    -- Muda o status PRIMEIRO: assim o CHECK ck_pedidos_producao_estoque
    -- deixa de exigir estoque_baixado = true e a devolução pode zerar a
    -- flag em devolver_estoque_pedido().
    update bloome.pedidos p
       set status = 'cancelado',
           motivo_cancelamento = coalesce(
               nullif(btrim(p_motivo), ''),
               'cancelado pelo administrador'
           )
     where p.id_pedidos = p_id_pedidos;

    if v_baixado then
        perform bloome.devolver_estoque_pedido(p_id_pedidos);
        return 'devolvido';
    end if;

    return 'sem_baixa';
end;
$$;

-- =====================================================================
-- 8. Recuperação de senha
-- =====================================================================

-- EC-50: revoga os tokens ativos anteriores e grava o novo. A validade
-- de 1h vem do DEFAULT da tabela (expira_em = now() + interval '1 hour').
create or replace function bloome.criar_recuperacao_senha(
    p_id_cliente integer,
    p_token_hash text
)
returns void
language plpgsql
set search_path = bloome, pg_temp
as $$
begin
    update bloome.recuperacao_senha
       set usado_em = now()
     where id_cliente = p_id_cliente
       and usado_em is null;

    insert into bloome.recuperacao_senha (id_cliente, token_hash)
    values (p_id_cliente, p_token_hash);
end;
$$;

-- EC-49: consume em um único UPDATE atômico. Devolve o id_cliente ou
-- NULL se o token não existe, já foi usado ou está expirado.
create or replace function bloome.consumir_reset_token(p_token_hash text)
returns integer
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_id_cliente integer;
begin
    update bloome.recuperacao_senha
       set usado_em = now()
     where token_hash = p_token_hash
       and usado_em is null
       and expira_em > now()
    returning id_cliente into v_id_cliente;

    return v_id_cliente;
end;
$$;

-- =====================================================================
-- 9. LGPD: anonimização
-- =====================================================================

-- EC-51: não apaga o cliente (a FK de pedidos impediria e o histórico
-- deve sobreviver). Troca os dados pessoais e marca anonimizado_em.
-- O e-mail aleatório respeita o unique parcial (só vale para
-- anonimizado_em IS NULL) e o formato normalizado do CHECK.
-- senha_hash aleatório de 64 caracteres satisfaz length >= 20 sem
-- depender da extensão pgcrypto (md5 é nativo).
create or replace function bloome.anonimizar_cliente(p_id_cliente integer)
returns void
language plpgsql
set search_path = bloome, pg_temp
as $$
begin
    update bloome.clientes c
       set nome = 'Cliente anonimizado',
           email = 'anon-' || replace(gen_random_uuid()::text, '-', '') || '@invalid.local',
           senha_hash = md5(random()::text) || md5(random()::text),
           anonimizado_em = now()
     where c.id_cliente = p_id_cliente;

    if not found then
        raise exception using
            errcode = 'P0002',
            message = 'cliente_inexistente',
            detail  = format('id_cliente=%s', p_id_cliente);
    end if;
end;
$$;

-- =====================================================================
-- 10. Trigger: matriz de transição de status
-- =====================================================================

-- EC-07/EC-33: única fonte da máquina de estados. Mesmo status é no-op.
-- Terminais: entregue e cancelado.
create or replace function bloome.validar_transicao_status()
returns trigger
language plpgsql
set search_path = bloome, pg_temp
as $$
begin
    if new.status = old.status then
        return new;
    end if;

    if not (
           (old.status = 'aguardando_pagamento'
                and new.status in ('pago', 'pago_sem_estoque', 'cancelado'))
        or (old.status = 'pago'
                and new.status in ('em_producao', 'cancelado'))
        or (old.status = 'pago_sem_estoque'
                and new.status in ('pago', 'cancelado'))
        or (old.status = 'em_producao'
                and new.status in ('pronto_para_retirada', 'enviado'))
        or (old.status = 'pronto_para_retirada'
                and new.status = 'entregue')
        or (old.status = 'enviado'
                and new.status = 'entregue')
    ) then
        raise exception using
            errcode = 'P0001',
            message = 'transicao_invalida',
            detail  = format('%s -> %s', old.status, new.status);
    end if;

    return new;
end;
$$;

-- =====================================================================
-- 11. Trigger: item vendável
-- =====================================================================

-- EC-08/EC-09/EC-10/EC-12/EC-20/EC-38:
--   * variação marcada 'esgotado' não vende;
--   * modelo 'removido' ou 'volta_em_breve' não vende;
--   * modelo sem pingente cadastrado, ou com pingente zerado, não vende;
--   * variação sem receita não vende;
--   * preço/custo são snapshots do checkout e NÃO são sobrescritos aqui.
-- Negatividade de preço/custo fica com os CHECKs ck_itens_preco e
-- ck_itens_custo do schema.
create or replace function bloome.validar_item_vendavel()
returns trigger
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_status_variacao text;
    v_status_modelo text;
    v_pingente_id integer;
    v_pingente_estoque numeric(12,3);
    v_preco numeric(10,2);
begin
    select v.status,
           a.status,
           a.pingente_insumo_id,
           a.valor_acessorario
      into v_status_variacao,
           v_status_modelo,
           v_pingente_id,
           v_preco
      from bloome.variacoes v
      join bloome.acessorios a on a.id_acessorios = v.id_acessorios
     where v.id_variacao = new.id_variacao;

    if not found then
        raise exception using
            errcode = 'P0002',
            message = 'variacao_inexistente',
            detail  = format('id_variacao=%s', new.id_variacao);
    end if;

    -- EC-12/EC-20: bloqueio manual da cor.
    if v_status_variacao = 'esgotado' then
        raise exception using
            errcode = 'P0001',
            message = 'variacao_esgotada',
            detail  = format('id_variacao=%s', new.id_variacao);
    end if;

    -- EC-09/EC-10: modelo retirado ou temporariamente fora.
    if v_status_modelo in ('removido', 'volta_em_breve') then
        raise exception using
            errcode = 'P0001',
            message = 'produto_indisponivel',
            detail  = format('status=%s', v_status_modelo);
    end if;

    -- EC-10: pingente explícito do modelo.
    if v_pingente_id is null then
        raise exception using
            errcode = 'P0001',
            message = 'sem_pingente',
            detail  = format('id_variacao=%s', new.id_variacao);
    end if;

    select i.quantidade_estoque
      into v_pingente_estoque
      from bloome.insumos i
     where i.id_insumos = v_pingente_id;

    if v_pingente_estoque is null or v_pingente_estoque <= 0 then
        raise exception using
            errcode = 'P0001',
            message = 'sem_pingente',
            detail  = format('id_insumos=%s', v_pingente_id);
    end if;

    -- EC-08: sem receita não há como produzir.
    if not exists (
        select 1
          from bloome.composicao_variacoes cv
         where cv.id_variacao = new.id_variacao
    ) then
        raise exception using
            errcode = 'P0002',
            message = 'produto_sem_receita',
            detail  = format('id_variacao=%s', new.id_variacao);
    end if;

    -- O pingente do modelo precisa estar na receita; senão a venda não o
    -- consome e o estoque dele nunca baixa.
    if not exists (
        select 1
          from bloome.composicao_variacoes cv
         where cv.id_variacao = new.id_variacao
           and cv.id_insumos = v_pingente_id
    ) then
        raise exception using
            errcode = 'P0001',
            message = 'pingente_fora_da_receita',
            detail  = format('id_variacao=%s id_insumos=%s',
                             new.id_variacao, v_pingente_id);
    end if;

    -- EC-38: o preço vem do modelo e o custo da receita. No INSERT (ou
    -- troca de variação) recalculamos; com a mesma variação, o snapshot
    -- é imutável para o cliente não adulterar o valor.
    if tg_op = 'INSERT'
       or (tg_op = 'UPDATE' and new.id_variacao is distinct from old.id_variacao)
    then
        new.preco_unitario := v_preco;
        new.custo_unitario := bloome.calcular_custo_variacao(new.id_variacao);
    elsif tg_op = 'UPDATE'
          and (new.preco_unitario is distinct from old.preco_unitario
               or new.custo_unitario is distinct from old.custo_unitario)
    then
        raise exception using
            errcode = 'P0001',
            message = 'snapshot_imutavel',
            detail  = format('id_item=%s', new.id_item);
    end if;

    return new;
end;
$$;

-- =====================================================================
-- 12. Trigger: recálculo dos totais do pedido
-- =====================================================================

-- EC-28/EC-29/EC-39: itens mudam em aguardando_pagamento e em
-- pago_sem_estoque (troca de cor, já que nada foi baixado). Fora disso,
-- qualquer INSERT/UPDATE/DELETE é bloqueado. O total nunca vem do app:
-- subtotal é a soma dos itens e valor_total = subtotal + frete
-- (frete NULL conta como 0).
create or replace function bloome.recalcular_pedido()
returns trigger
language plpgsql
set search_path = bloome, pg_temp
as $$
declare
    v_id_pedidos integer;
    v_status text;
begin
    if tg_op = 'DELETE' then
        v_id_pedidos := old.id_pedidos;
    else
        v_id_pedidos := new.id_pedidos;
    end if;

    -- Item não muda de pedido: evita deixar o total do pedido antigo
    -- desatualizado silenciosamente.
    if tg_op = 'UPDATE' then
        if old.id_pedidos is distinct from new.id_pedidos then
            raise exception using
                errcode = 'P0001',
                message = 'pedido_do_item_imutavel',
                detail  = format('id_item=%s %s -> %s',
                                 new.id_item, old.id_pedidos, new.id_pedidos);
        end if;
    end if;

    -- EC-39: trava o pedido pai e confere o status. O lock também
    -- serializa dois itens inseridos ao mesmo tempo no mesmo pedido.
    select p.status
      into v_status
      from bloome.pedidos p
     where p.id_pedidos = v_id_pedidos
       for update;

    if not found then
        raise exception using
            errcode = 'P0002',
            message = 'pedido_inexistente',
            detail  = format('id_pedidos=%s', v_id_pedidos);
    end if;

    -- pago_sem_estoque também aceita troca de cor: nada foi baixado ainda.
    if v_status not in ('aguardando_pagamento', 'pago_sem_estoque') then
        raise exception using
            errcode = 'P0001',
            message = 'pedido_ja_processado',
            detail  = format('status=%s', v_status);
    end if;

    -- EC-28/EC-29: um único UPDATE com subquery agregada.
    update bloome.pedidos p
       set subtotal = coalesce((
               select sum(ip.quantidade * ip.preco_unitario)
                 from bloome.itens_pedidos ip
                where ip.id_pedidos = p.id_pedidos
           ), 0),
           valor_total = coalesce((
               select sum(ip.quantidade * ip.preco_unitario)
                 from bloome.itens_pedidos ip
                where ip.id_pedidos = p.id_pedidos
           ), 0) + coalesce(p.frete_valor, 0)
     where p.id_pedidos = v_id_pedidos;

    return null;
end;
$$;

-- =====================================================================
-- 13. Trigger: evento de pagamento (assinatura)
-- =====================================================================

-- EC-24: evento com assinatura inválida não pode virar 'processado'.
-- EC-23/EC-26: o UNIQUE(gateway, evento_id) do schema cuida da
-- repetição; aqui garantimos a integridade da assinatura.
create or replace function bloome.validar_evento()
returns trigger
language plpgsql
set search_path = bloome, pg_temp
as $$
begin
    if new.status_evento = 'processado' and new.assinatura_valida = false then
        raise exception using
            errcode = 'P0001',
            message = 'assinatura_invalida',
            detail  = format('gateway=%s evento_id=%s', new.gateway, new.evento_id);
    end if;

    if new.status_evento = 'processado' and new.processado_em is null then
        new.processado_em := now();
    end if;

    return new;
end;
$$;

-- EC-28/EC-29: mantém valor_total coerente no INSERT e quando o frete
-- muda. Sem isso, atualizar só frete_valor violaria
-- ck_pedidos_total_coerente.
create or replace function bloome.fn_recalcular_total_pedido()
returns trigger
language plpgsql
set search_path = bloome, pg_temp
as $$
begin
    new.valor_total := new.subtotal + coalesce(new.frete_valor, 0);
    return new;
end;
$$;

-- =====================================================================
-- 14. Triggers
-- =====================================================================

-- 14.1 atualizado_em nas tabelas que têm a coluna.
drop trigger if exists trg_insumos_atualizado_em on bloome.insumos;
create trigger trg_insumos_atualizado_em
    before update on bloome.insumos
    for each row execute function bloome.fn_atualizado_em();

drop trigger if exists trg_acessorios_atualizado_em on bloome.acessorios;
create trigger trg_acessorios_atualizado_em
    before update on bloome.acessorios
    for each row execute function bloome.fn_atualizado_em();

drop trigger if exists trg_variacoes_atualizado_em on bloome.variacoes;
create trigger trg_variacoes_atualizado_em
    before update on bloome.variacoes
    for each row execute function bloome.fn_atualizado_em();

drop trigger if exists trg_usuarios_atualizado_em on bloome.usuarios;
create trigger trg_usuarios_atualizado_em
    before update on bloome.usuarios
    for each row execute function bloome.fn_atualizado_em();

drop trigger if exists trg_clientes_atualizado_em on bloome.clientes;
create trigger trg_clientes_atualizado_em
    before update on bloome.clientes
    for each row execute function bloome.fn_atualizado_em();

drop trigger if exists trg_pedidos_atualizado_em on bloome.pedidos;
create trigger trg_pedidos_atualizado_em
    before update on bloome.pedidos
    for each row execute function bloome.fn_atualizado_em();

-- 14.2 Matriz de transição de status do pedido.
drop trigger if exists trg_pedidos_validar_transicao on bloome.pedidos;
create trigger trg_pedidos_validar_transicao
    before update of status on bloome.pedidos
    for each row execute function bloome.validar_transicao_status();

-- 14.3 Item só entra/altera se for vendável.
drop trigger if exists trg_itens_validar_vendavel on bloome.itens_pedidos;
create trigger trg_itens_validar_vendavel
    before insert or update on bloome.itens_pedidos
    for each row execute function bloome.validar_item_vendavel();

-- 14.4 Totais do pedido recalculados a cada mudança de item.
drop trigger if exists trg_itens_recalcular_pedido on bloome.itens_pedidos;
create trigger trg_itens_recalcular_pedido
    after insert or update or delete on bloome.itens_pedidos
    for each row execute function bloome.recalcular_pedido();

-- 14.5 Evento de pagamento com assinatura íntegra.
drop trigger if exists trg_eventos_validar on bloome.eventos_pagamento;
create trigger trg_eventos_validar
    before insert or update on bloome.eventos_pagamento
    for each row execute function bloome.validar_evento();

-- 14.6 Total do pedido coerente em INSERT/UPDATE de subtotal/frete.
drop trigger if exists trg_pedidos_recalcular_total on bloome.pedidos;
create trigger trg_pedidos_recalcular_total
    before insert or update of subtotal, frete_valor on bloome.pedidos
    for each row execute function bloome.fn_recalcular_total_pedido();

-- 14.7 EC-09/EC-51: produto e cliente não sofrem DELETE físico.
create or replace function bloome.bloquear_delete_historico()
returns trigger
language plpgsql
set search_path = bloome, pg_temp
as $$
begin
    raise exception using
        errcode = 'P0001',
        message = 'delete_fisico_proibido',
        detail  = format('tabela=%s', tg_table_name);
end;
$$;

drop trigger if exists trg_acessorios_sem_delete on bloome.acessorios;
create trigger trg_acessorios_sem_delete
    before delete on bloome.acessorios
    for each row execute function bloome.bloquear_delete_historico();

drop trigger if exists trg_clientes_sem_delete on bloome.clientes;
create trigger trg_clientes_sem_delete
    before delete on bloome.clientes
    for each row execute function bloome.bloquear_delete_historico();

commit;

-- =====================================================================
-- COBERTURA DAS EDGE CASES (matriz docs/PLANO-BANCO-BLOOME.md §7.1)
--   EC-01/02/03/04  verificar_estoque_pedido + confirmar_pagamento
--   EC-05           pago_sem_estoque sem baixa
--   EC-06/EC-07     cancelar_pedido + devolver_estoque_pedido
--   EC-08           produto_sem_receita (P0002) em 3 pontos
--   EC-09/EC-10     validar_item_vendavel (removido/volta_em_breve/sem pingente)
--   EC-12/EC-20     validar_item_vendavel (variacao esgotada)
--   EC-23/EC-25/EC-26  confirmar_pagamento + validar_evento
--   EC-24           assinatura inválida não vira processado
--   EC-27           garantido pelo UNIQUE do schema (não pela função)
--   EC-28/EC-29     recalcular_pedido
--   EC-33           validar_transicao_status (P0001)
--   EC-38           preço/custo calculados no INSERT e imutáveis na mesma variação
--   EC-39           recalcular_pedido bloqueia fora de aguardando/pago_sem_estoque
--   EC-40/EC-41     baixar_estoque_pedido (P0003 + locks ordenados)
--   EC-42           cancelar_pedido registra motivo; reembolso manual
--   EC-43/EC-44     coerência status x estoque_baixado (CHECK + ordem)
--   EC-49/EC-50     consumir_reset_token + criar_recuperacao_senha
--   EC-51           anonimizar_cliente
-- =====================================================================
