-- =====================================================================
-- Bloome — 99_tests.sql
--
-- Testes T01..T28 da matriz de edge cases (docs/PLANO-BANCO-BLOOME.md §7.1).
--
-- COMO RODAR (SQL Editor do Supabase):
--   * Rode depois de 01_schema.sql, 02_funcoes.sql e 03_views.sql.
--   * Rode o arquivo inteiro; cada teste é um bloco BEGIN ... ROLLBACK.
--   * NADA fica gravado: todo bloco termina em ROLLBACK.
--   * Sucesso: mensagem `T## OK` (NOTICE).
--   * Falha: exceção `T## FALHOU: ...` — o teste aponta o que quebrou.
--
-- Padrão dos testes negativos: a exceção esperada é capturada e conferida
-- por SQLSTATE e/ou nome da constraint; se NÃO ocorrer, o teste falha.
-- Nomes de fixture têm o número do teste no final (fio-t07, etc.), então
-- os blocos não colidem mesmo que falhem no meio.
-- =====================================================================


-- =====================================================================
-- T01 — estoque suficiente: checkout não baixa, pagamento baixa 1x
--        (EC-01/EC-03/EC-04/EC-38)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_res text;
    v_qtd numeric(12,3);
    v_snap jsonb;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t01', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t01', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t01', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T01', 'cliente.t01@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 2, 0, 0);

    -- EC-03: o checkout não pode baixar estoque.
    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 10 then
        raise exception 'T01 FALHOU: estoque baixou no checkout: %', v_qtd;
    end if;

    -- EC-38: preço do modelo e custo da receita gravados pelo trigger.
    if not exists (
        select 1 from bloome.itens_pedidos
         where id_pedidos = v_ped
           and preco_unitario = 20.00
           and custo_unitario = 6.00
    ) then
        raise exception 'T01 FALHOU: snapshot de preco/custo incorreto';
    end if;

    v_res := bloome.confirmar_pagamento(v_ped, null, null);
    if v_res <> 'pago' then
        raise exception 'T01 FALHOU: resultado do pagamento = %', v_res;
    end if;

    if not exists (
        select 1 from bloome.pedidos
         where id_pedidos = v_ped
           and status = 'pago'
           and estoque_baixado = true
    ) then
        raise exception 'T01 FALHOU: pedido nao ficou pago com estoque baixado';
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 8 then
        raise exception 'T01 FALHOU: fio deveria ser 8, ficou %', v_qtd;
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_ping;
    if v_qtd <> 8 then
        raise exception 'T01 FALHOU: pingente deveria ser 8, ficou %', v_qtd;
    end if;

    select consumo_snapshot into v_snap from bloome.pedidos where id_pedidos = v_ped;
    if v_snap is null
       or (v_snap ? (v_fio::text)) is not true
       or (v_snap ? (v_ping::text)) is not true then
        raise exception 'T01 FALHOU: consumo_snapshot nao registrou os insumos';
    end if;

    select subtotal into v_qtd from bloome.pedidos where id_pedidos = v_ped;
    if v_qtd <> 40.00 then
        raise exception 'T01 FALHOU: subtotal deveria ser 40, ficou %', v_qtd;
    end if;

    raise notice 'T01 OK: checkout sem baixa; pagamento baixou uma vez';
end $$;
rollback;


-- =====================================================================
-- T02 — estoque insuficiente no pagamento -> pago_sem_estoque
--        (EC-04/EC-05/EC-43)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_res text;
    v_qtd numeric(12,3);
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t02', 2.00, 5, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t02', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t02', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T02', 'cliente.t02@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    -- Checkout não valida saldo (o pré-check é do app); o banco valida no pagamento.
    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 6, 0, 0);

    v_res := bloome.confirmar_pagamento(v_ped, null, null);
    if v_res <> 'pago_sem_estoque' then
        raise exception 'T02 FALHOU: resultado = % (esperava pago_sem_estoque)', v_res;
    end if;

    if not exists (
        select 1 from bloome.pedidos
         where id_pedidos = v_ped
           and status = 'pago_sem_estoque'
           and estoque_baixado = false
    ) then
        raise exception 'T02 FALHOU: status/estoque_baixado incoerentes';
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 5 then
        raise exception 'T02 FALHOU: estoque mudou sem pagamento valido: %', v_qtd;
    end if;

    -- Pedido sem baixa pode ser cancelado sem devolver nada.
    v_res := bloome.cancelar_pedido(v_ped, 'sem estoque');
    if v_res <> 'sem_baixa' then
        raise exception 'T02 FALHOU: cancelamento = % (esperava sem_baixa)', v_res;
    end if;

    raise notice 'T02 OK: pago_sem_estoque, sem baixa, cancelamento sem devolucao';
end $$;
rollback;


-- =====================================================================
-- T03 — webhook repetido -> uma única baixa (EC-23)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_res text;
    v_qtd numeric(12,3);
    v_status_evento text;
    v_tentativas integer;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t03', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t03', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t03', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T03', 'cliente.t03@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    insert into bloome.eventos_pagamento (gateway, evento_id, payload, assinatura_valida)
    values ('mercadopago', 'evt-t03', '{"status":"approved"}'::jsonb, true);

    v_res := bloome.confirmar_pagamento(v_ped, 'mercadopago', 'evt-t03');
    if v_res <> 'pago' then
        raise exception 'T03 FALHOU: primeira confirmacao = %', v_res;
    end if;

    select status_evento, tentativas
      into v_status_evento, v_tentativas
      from bloome.eventos_pagamento
     where gateway = 'mercadopago' and evento_id = 'evt-t03';

    if v_status_evento <> 'processado' then
        raise exception 'T03 FALHOU: evento nao foi processado: %', v_status_evento;
    end if;

    -- O mesmo webhook chega de novo.
    v_res := bloome.confirmar_pagamento(v_ped, 'mercadopago', 'evt-t03');
    if v_res <> 'ja_processado' then
        raise exception 'T03 FALHOU: segunda confirmacao = % (esperava ja_processado)', v_res;
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 9 then
        raise exception 'T03 FALHOU: baixa duplicada; fio = %', v_qtd;
    end if;

    select tentativas into v_tentativas
      from bloome.eventos_pagamento
     where gateway = 'mercadopago' and evento_id = 'evt-t03';
    if v_tentativas <> 1 then
        raise exception 'T03 FALHOU: tentativas = % (esperava 1)', v_tentativas;
    end if;

    raise notice 'T03 OK: webhook repetido nao baixou duas vezes';
end $$;
rollback;


-- =====================================================================
-- T04 — cancelar antes de produzir devolve o estoque uma vez (EC-06)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_res text;
    v_qtd numeric(12,3);
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t04', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t04', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t04', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T04', 'cliente.t04@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 2, 0, 0);

    perform bloome.confirmar_pagamento(v_ped, null, null);

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 8 then
        raise exception 'T04 FALHOU: apos pagar, fio = % (esperava 8)', v_qtd;
    end if;

    v_res := bloome.cancelar_pedido(v_ped, 'desistiu antes da producao');
    if v_res <> 'devolvido' then
        raise exception 'T04 FALHOU: cancelamento = % (esperava devolvido)', v_res;
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 10 then
        raise exception 'T04 FALHOU: devolucao incorreta; fio = % (esperava 10)', v_qtd;
    end if;

    if not exists (
        select 1 from bloome.pedidos
         where id_pedidos = v_ped
           and status = 'cancelado'
           and estoque_baixado = false
           and motivo_cancelamento is not null
    ) then
        raise exception 'T04 FALHOU: pedido cancelado sem motivo ou flag inconsistente';
    end if;

    -- Segunda devolução não pode acontecer.
    begin
        perform bloome.cancelar_pedido(v_ped, 'de novo');
    exception when others then
        if sqlerrm like '%transicao_invalida%' then
            v_ok := true;
        else
            raise exception 'T04 FALHOU: excecao inesperada: % (%)', sqlstate, sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T04 FALHOU: cancelamento duplicado foi aceito';
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 10 then
        raise exception 'T04 FALHOU: devolveu duas vezes; fio = %', v_qtd;
    end if;

    raise notice 'T04 OK: cancelar antes de produzir devolveu uma unica vez';
end $$;
rollback;


-- =====================================================================
-- T05 — cancelar depois de produzir é recusado (EC-07/EC-33)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_qtd numeric(12,3);
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t05', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t05', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t05', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T05', 'cliente.t05@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    perform bloome.confirmar_pagamento(v_ped, null, null);
    update bloome.pedidos set status = 'em_producao' where id_pedidos = v_ped;

    begin
        perform bloome.cancelar_pedido(v_ped, 'tarde demais');
    exception when others then
        if sqlerrm like '%transicao_invalida%' then
            v_ok := true;
        else
            raise exception 'T05 FALHOU: excecao inesperada: % (%)', sqlstate, sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T05 FALHOU: cancelamento depois de produzir foi aceito';
    end if;

    if not exists (
        select 1 from bloome.pedidos
         where id_pedidos = v_ped and status = 'em_producao'
    ) then
        raise exception 'T05 FALHOU: status do pedido mudou';
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 9 then
        raise exception 'T05 FALHOU: estoque devolvido indevidamente: %', v_qtd;
    end if;

    raise notice 'T05 OK: cancelamento apos producao recusado';
end $$;
rollback;


-- =====================================================================
-- T06 — dois pedidos disputando o mesmo insumo: sem estoque negativo
--        (EC-40/EC-41)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped_a integer;
    v_ped_b integer;
    v_res text;
    v_qtd numeric(12,3);
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t06', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t06', 4.00, 20, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t06', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T06', 'cliente.t06@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped_a;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped_b;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped_a, v_var, 6, 0, 0);

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped_b, v_var, 6, 0, 0);

    v_res := bloome.confirmar_pagamento(v_ped_a, null, null);
    if v_res <> 'pago' then
        raise exception 'T06 FALHOU: pedido A = %', v_res;
    end if;

    v_res := bloome.confirmar_pagamento(v_ped_b, null, null);
    if v_res <> 'pago_sem_estoque' then
        raise exception 'T06 FALHOU: pedido B = % (esperava pago_sem_estoque)', v_res;
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 4 then
        raise exception 'T06 FALHOU: fio = % (esperava 4)', v_qtd;
    end if;

    -- Chamada direta da baixa também precisa recusar.
    begin
        perform bloome.baixar_estoque_pedido(v_ped_b);
    exception when others then
        if sqlstate = 'P0003' then
            v_ok := true;
        else
            raise exception 'T06 FALHOU: excecao inesperada: % (%)', sqlstate, sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T06 FALHOU: baixa direta passou do estoque disponivel';
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd < 0 then
        raise exception 'T06 FALHOU: estoque ficou negativo: %', v_qtd;
    end if;

    raise notice 'T06 OK: disputa pelo insumo nao gerou estoque negativo';
end $$;
rollback;


-- =====================================================================
-- T07 — variação sem receita não vende (EC-08)
-- =====================================================================
begin;
do $$
declare
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t07', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t07', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T07', 'cliente.t07@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    begin
        insert into bloome.itens_pedidos
            (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
        values (v_ped, v_var, 1, 0, 0);
    exception when others then
        if sqlstate = 'P0002' and sqlerrm like '%produto_sem_receita%' then
            v_ok := true;
        else
            raise exception 'T07 FALHOU: excecao inesperada: % (%)', sqlstate, sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T07 FALHOU: item sem receita foi aceito';
    end if;

    if exists (select 1 from bloome.itens_pedidos where id_pedidos = v_ped) then
        raise exception 'T07 FALHOU: item sem receita ficou gravado';
    end if;

    raise notice 'T07 OK: produto sem receita bloqueado';
end $$;
rollback;


-- =====================================================================
-- T08 — cor duplicada no modelo e item duplicado no pedido (EC-14/EC-37)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_constraint text;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t08', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t08', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t08', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    -- EC-14: mesma cor no mesmo modelo.
    begin
        insert into bloome.variacoes (id_acessorios, cor, cor_hex)
        values (v_modelo, 'preto', '#111111');
    exception when unique_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'uq_variacoes_modelo_cor');
    end;
    if not v_ok then
        raise exception 'T08 FALHOU: cor duplicada foi aceita';
    end if;

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T08', 'cliente.t08@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    -- EC-37: mesmo item duas vezes no mesmo pedido.
    v_ok := false;
    begin
        insert into bloome.itens_pedidos
            (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
        values (v_ped, v_var, 1, 0, 0);
    exception when unique_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'uq_itens_pedido_variacao');
    end;
    if not v_ok then
        raise exception 'T08 FALHOU: item duplicado foi aceito';
    end if;

    if (select count(*) from bloome.itens_pedidos where id_pedidos = v_ped) <> 1 then
        raise exception 'T08 FALHOU: pedido ficou com mais de um item';
    end if;

    raise notice 'T08 OK: cor e item duplicados bloqueados';
end $$;
rollback;


-- =====================================================================
-- T09 — duas cores do mesmo modelo no mesmo pedido (EC-36)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_preto integer;
    v_marrom integer;
    v_cli integer;
    v_ped integer;
    v_subtotal numeric(10,2);
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t09', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t09', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t09', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_preto;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'marrom', '#4B3621')
    returning id_variacao into v_marrom;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_preto, v_fio, 1), (v_preto, v_ping, 1),
           (v_marrom, v_fio, 1), (v_marrom, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T09', 'cliente.t09@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_preto, 2, 0, 0);

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_marrom, 1, 0, 0);

    if (select count(*) from bloome.itens_pedidos where id_pedidos = v_ped) <> 2 then
        raise exception 'T09 FALHOU: o pedido nao aceitou duas cores do mesmo modelo';
    end if;

    select subtotal into v_subtotal from bloome.pedidos where id_pedidos = v_ped;
    if v_subtotal <> 60.00 then
        raise exception 'T09 FALHOU: subtotal = % (esperava 60)', v_subtotal;
    end if;

    raise notice 'T09 OK: duas cores do mesmo modelo no mesmo pedido';
end $$;
rollback;


-- =====================================================================
-- T10 — método de pagamento e transições inválidas (EC-21/EC-22/EC-33)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_constraint text;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t10', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t10', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t10', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T10', 'cliente.t10@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    -- EC-22: boleto/dinheiro fora.
    begin
        insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
        values (v_cli, 'loja', 'dinheiro', 'retirada');
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_pedidos_metodo');
    end;
    if not v_ok then
        raise exception 'T10 FALHOU: metodo de pagamento invalido foi aceito';
    end if;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    -- EC-33: aguardando_pagamento não pula direto para entregue.
    v_ok := false;
    begin
        update bloome.pedidos set status = 'entregue' where id_pedidos = v_ped;
    exception when others then
        if sqlerrm like '%transicao_invalida%' then
            v_ok := true;
        else
            raise exception 'T10 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T10 FALHOU: salto de status invalido foi aceito';
    end if;

    perform bloome.confirmar_pagamento(v_ped, null, null);
    update bloome.pedidos set status = 'em_producao' where id_pedidos = v_ped;

    -- EC-07: em_producao -> cancelado não existe.
    v_ok := false;
    begin
        update bloome.pedidos set status = 'cancelado' where id_pedidos = v_ped;
    exception when others then
        if sqlerrm like '%transicao_invalida%' then
            v_ok := true;
        else
            raise exception 'T10 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T10 FALHOU: em_producao -> cancelado foi aceito';
    end if;

    -- Caminho válido: em_producao -> pronto_para_retirada -> entregue.
    update bloome.pedidos set status = 'pronto_para_retirada' where id_pedidos = v_ped;
    update bloome.pedidos set status = 'entregue' where id_pedidos = v_ped;

    if not exists (
        select 1 from bloome.pedidos where id_pedidos = v_ped and status = 'entregue'
    ) then
        raise exception 'T10 FALHOU: caminho valido ate entregue nao funcionou';
    end if;

    raise notice 'T10 OK: metodo e transicoes invalidos recusados; caminho valido ok';
end $$;
rollback;


-- =====================================================================
-- T11 — endereço condicional, CEP e UF (EC-30/EC-31/EC-32)
-- =====================================================================
begin;
do $$
declare
    v_cli integer;
    v_ped integer;
    v_constraint text;
    v_ok boolean := false;
begin
    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T11', 'cliente.t11@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    -- Correios sem endereço.
    begin
        insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
        values (v_cli, 'cliente', 'pix', 'correios');
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_pedidos_endereco');
    end;
    if not v_ok then
        raise exception 'T11 FALHOU: Correios sem endereco foi aceito';
    end if;

    -- CEP inválido.
    v_ok := false;
    begin
        insert into bloome.pedidos
            (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega,
             cep, logradouro, numero, bairro, cidade, uf)
        values (v_cli, 'cliente', 'pix', 'correios',
                '5700', 'Rua Teste', '10', 'Centro', 'Maceio', 'AL');
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_pedidos_cep');
    end;
    if not v_ok then
        raise exception 'T11 FALHOU: CEP invalido foi aceito';
    end if;

    -- UF minúscula.
    v_ok := false;
    begin
        insert into bloome.pedidos
            (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega,
             cep, logradouro, numero, bairro, cidade, uf)
        values (v_cli, 'cliente', 'pix', 'correios',
                '57000000', 'Rua Teste', '10', 'Centro', 'Maceio', 'al');
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_pedidos_uf');
    end;
    if not v_ok then
        raise exception 'T11 FALHOU: UF minuscula foi aceita';
    end if;

    -- Retirada com endereço.
    v_ok := false;
    begin
        insert into bloome.pedidos
            (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega,
             cep, logradouro, numero, bairro, cidade, uf)
        values (v_cli, 'loja', 'pix', 'retirada',
                '57000000', 'Rua Teste', '10', 'Centro', 'Maceio', 'AL');
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_pedidos_endereco');
    end;
    if not v_ok then
        raise exception 'T11 FALHOU: retirada com endereco foi aceita';
    end if;

    -- Retirada com frete cobrado.
    v_ok := false;
    begin
        insert into bloome.pedidos
            (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega, frete_valor)
        values (v_cli, 'loja', 'pix', 'retirada', 10.00);
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_pedidos_retirada_frete');
    end;
    if not v_ok then
        raise exception 'T11 FALHOU: retirada com frete foi aceita';
    end if;

    -- Uber Flash com endereço.
    v_ok := false;
    begin
        insert into bloome.pedidos
            (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega,
             cep, logradouro, numero, bairro, cidade, uf)
        values (v_cli, 'cliente', 'pix', 'uber_flash',
                '57000000', 'Rua Teste', '10', 'Centro', 'Maceio', 'AL');
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_pedidos_endereco');
    end;
    if not v_ok then
        raise exception 'T11 FALHOU: Uber Flash com endereco foi aceito';
    end if;

    -- Endereço válido.
    insert into bloome.pedidos
        (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega,
         cep, logradouro, numero, bairro, cidade, uf)
    values (v_cli, 'cliente', 'pix', 'correios',
            '57000000', 'Rua Teste', '10', 'Centro', 'Maceio', 'AL')
    returning id_pedidos into v_ped;

    raise notice 'T11 OK: endereco, CEP e UF conferidos por modalidade';
end $$;
rollback;


-- =====================================================================
-- T12 — total mantido pelo banco e item imutável após pagamento
--        (EC-28/EC-29/EC-39)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_ped2 integer;
    v_total numeric(10,2);
    v_subtotal numeric(10,2);
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t12', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t12', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t12', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T12', 'cliente.t12@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    -- Valor total adulterado no INSERT é corrigido pelo trigger.
    insert into bloome.pedidos
        (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega,
         subtotal, frete_valor, valor_total)
    values (v_cli, 'cliente', 'pix', 'uber_flash', 10.00, 5.00, 999.00)
    returning id_pedidos into v_ped;

    select subtotal, valor_total into v_subtotal, v_total
      from bloome.pedidos where id_pedidos = v_ped;
    if v_subtotal <> 10.00 or v_total <> 15.00 then
        raise exception 'T12 FALHOU: total adulterado nao foi corrigido (%, %)', v_subtotal, v_total;
    end if;

    -- Mudar só o frete mantém o total coerente.
    update bloome.pedidos set frete_valor = 7.00 where id_pedidos = v_ped;
    select valor_total into v_total from bloome.pedidos where id_pedidos = v_ped;
    if v_total <> 17.00 then
        raise exception 'T12 FALHOU: total apos frete = % (esperava 17)', v_total;
    end if;

    -- Item entra e o subtotal é recalculado.
    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    select subtotal, valor_total into v_subtotal, v_total
      from bloome.pedidos where id_pedidos = v_ped;
    if v_subtotal <> 20.00 or v_total <> 27.00 then
        raise exception 'T12 FALHOU: subtotal/total apos item = %, %', v_subtotal, v_total;
    end if;

    perform bloome.confirmar_pagamento(v_ped, null, null);

    -- EC-39: item não muda com pedido pago.
    begin
        update bloome.itens_pedidos
           set quantidade = 2
         where id_pedidos = v_ped;
    exception when others then
        if sqlerrm like '%pedido_ja_processado%' then
            v_ok := true;
        else
            raise exception 'T12 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T12 FALHOU: item alterado depois do pagamento';
    end if;

    -- Frete NULL (retirada) não quebra o total.
    insert into bloome.pedidos
        (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega, subtotal)
    values (v_cli, 'loja', 'pix', 'retirada', 10.00)
    returning id_pedidos into v_ped2;

    select valor_total into v_total from bloome.pedidos where id_pedidos = v_ped2;
    if v_total <> 10.00 then
        raise exception 'T12 FALHOU: frete NULL gerou total %', v_total;
    end if;

    raise notice 'T12 OK: total pelo banco e item imutavel depois do pagamento';
end $$;
rollback;


-- =====================================================================
-- T13 — checkout idempotente (EC-27)
-- =====================================================================
begin;
do $$
declare
    v_cli integer;
    v_constraint text;
    v_qtd integer;
    v_ok boolean := false;
begin
    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T13', 'cliente.t13@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos
        (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega, idempotencia)
    values (v_cli, 'loja', 'pix', 'retirada',
            '11111111-1111-1111-1111-111111111111')
    on conflict (idempotencia) do nothing;

    insert into bloome.pedidos
        (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega, idempotencia)
    values (v_cli, 'loja', 'pix', 'retirada',
            '11111111-1111-1111-1111-111111111111')
    on conflict (idempotencia) do nothing;

    select count(*) into v_qtd
      from bloome.pedidos
     where idempotencia = '11111111-1111-1111-1111-111111111111';

    if v_qtd <> 1 then
        raise exception 'T13 FALHOU: double submit criou % pedidos', v_qtd;
    end if;

    -- INSERT direto duplicado também é barrado.
    begin
        insert into bloome.pedidos
            (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega, idempotencia)
        values (v_cli, 'loja', 'pix', 'retirada',
                '11111111-1111-1111-1111-111111111111');
    exception when unique_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'uq_pedidos_idempotencia');
    end;
    if not v_ok then
        raise exception 'T13 FALHOU: idempotencia duplicada foi aceita';
    end if;

    raise notice 'T13 OK: double submit de checkout bloqueado';
end $$;
rollback;


-- =====================================================================
-- T14 — e-mail normalizado, admin único e hash de senha (EC-45/46/47/48)
-- =====================================================================
begin;
do $$
declare
    v_cli integer;
    v_constraint text;
    v_ok boolean := false;
begin
    -- E-mail fora do padrão normalizado.
    begin
        insert into bloome.clientes (nome, email, senha_hash)
        values ('Cliente T14', 'Cliente.T14@Teste.Local', repeat('x', 60));
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_clientes_email_norm');
    end;
    if not v_ok then
        raise exception 'T14 FALHOU: e-mail sem normalizacao foi aceito';
    end if;

    -- Hash curto.
    v_ok := false;
    begin
        insert into bloome.clientes (nome, email, senha_hash)
        values ('Cliente T14', 'cliente.t14@teste.local', '123');
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_clientes_hash');
    end;
    if not v_ok then
        raise exception 'T14 FALHOU: hash curto foi aceito';
    end if;

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T14', 'cliente.t14@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    -- EC-46: mesmo e-mail (já normalizado) duplicado.
    v_ok := false;
    begin
        insert into bloome.clientes (nome, email, senha_hash)
        values ('Outro', 'cliente.t14@teste.local', repeat('y', 60));
    exception when unique_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ux_clientes_email_ativo');
    end;
    if not v_ok then
        raise exception 'T14 FALHOU: e-mail duplicado foi aceito';
    end if;

    -- EC-47: só um admin.
    insert into bloome.usuarios (usuario, senha_hash)
    values ('admin-t14', repeat('z', 60));

    v_ok := false;
    begin
        insert into bloome.usuarios (usuario, senha_hash)
        values ('admin2-t14', repeat('z', 60));
    exception when unique_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'uq_usuarios_single');
    end;
    if not v_ok then
        raise exception 'T14 FALHOU: segundo admin foi aceito';
    end if;

    raise notice 'T14 OK: e-mail, senha e admin unico conferidos';
end $$;
rollback;


-- =====================================================================
-- T15 — token de reset: validade, uso único e revogação (EC-49/EC-50)
-- =====================================================================
begin;
do $$
declare
    v_cli integer;
    v_token_a text := repeat('a', 64);
    v_token_b text := repeat('b', 64);
    v_token_c text := repeat('c', 64);
    v_ret integer;
    v_usado timestamptz;
begin
    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T15', 'cliente.t15@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    -- Token A é criado e depois revogado pela criação do token B.
    perform bloome.criar_recuperacao_senha(v_cli, v_token_a);
    perform bloome.criar_recuperacao_senha(v_cli, v_token_b);

    select usado_em into v_usado
      from bloome.recuperacao_senha where token_hash = v_token_a;
    if v_usado is null then
        raise exception 'T15 FALHOU: token anterior nao foi revogado';
    end if;

    -- Token consumido só funciona uma vez.
    v_ret := bloome.consumir_reset_token(v_token_b);
    if v_ret <> v_cli then
        raise exception 'T15 FALHOU: token valido nao foi consumido';
    end if;

    v_ret := bloome.consumir_reset_token(v_token_b);
    if v_ret is not null then
        raise exception 'T15 FALHOU: token foi reutilizado';
    end if;

    -- Token expirado.
    insert into bloome.recuperacao_senha
        (id_cliente, token_hash, criado_em, expira_em)
    values (v_cli, v_token_c, now() - interval '2 hours', now() - interval '1 hour');

    v_ret := bloome.consumir_reset_token(v_token_c);
    if v_ret is not null then
        raise exception 'T15 FALHOU: token expirado foi aceito';
    end if;

    raise notice 'T15 OK: reset expirado, reutilizado e revogado bloqueados';
end $$;
rollback;


-- =====================================================================
-- T16 — evento de pagamento chega antes do pedido (EC-25)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_evt integer;
    v_res text;
    v_ped_do_evento integer;
    v_status_evento text;
begin
    insert into bloome.eventos_pagamento
        (gateway, evento_id, payload, assinatura_valida, status_evento)
    values ('mercadopago', 'evt-t16', '{"status":"approved"}'::jsonb,
            true, 'aguardando_pedido')
    returning id_evento into v_evt;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t16', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t16', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t16', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T16', 'cliente.t16@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    v_res := bloome.confirmar_pagamento(v_ped, 'mercadopago', 'evt-t16');
    if v_res <> 'pago' then
        raise exception 'T16 FALHOU: confirmacao = %', v_res;
    end if;

    select id_pedidos, status_evento
      into v_ped_do_evento, v_status_evento
      from bloome.eventos_pagamento
     where id_evento = v_evt;

    if v_ped_do_evento is distinct from v_ped or v_status_evento <> 'processado' then
        raise exception 'T16 FALHOU: evento nao foi vinculado ao pedido';
    end if;

    raise notice 'T16 OK: evento antecipado vinculado ao pedido';
end $$;
rollback;


-- =====================================================================
-- T17 — assinatura, dois gateways e ausência de dado de cartão
--        (EC-24/EC-26/EC-52)
-- =====================================================================
begin;
do $$
declare
    v_constraint text;
    v_qtd integer;
    v_ok boolean := false;
begin
    -- Evento processado sem assinatura válida.
    begin
        insert into bloome.eventos_pagamento
            (gateway, evento_id, payload, assinatura_valida, status_evento)
        values ('mercadopago', 'evt-t17-a', '{}'::jsonb, false, 'processado');
    exception when others then
        if sqlerrm like '%assinatura_invalida%' then
            v_ok := true;
        else
            raise exception 'T17 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T17 FALHOU: evento sem assinatura virou processado';
    end if;

    -- Gateway com maiúsculas.
    v_ok := false;
    begin
        insert into bloome.eventos_pagamento
            (gateway, evento_id, payload, assinatura_valida)
        values ('MercadoPago', 'evt-t17-b', '{}'::jsonb, true);
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_eventos_gateway_norm');
    end;
    if not v_ok then
        raise exception 'T17 FALHOU: gateway fora do padrao foi aceito';
    end if;

    -- Mesmo evento_id em gateways diferentes é permitido.
    insert into bloome.eventos_pagamento
        (gateway, evento_id, payload, assinatura_valida)
    values ('mercadopago', 'evt-t17-c', '{}'::jsonb, true),
           ('pagseguro', 'evt-t17-c', '{}'::jsonb, true);

    -- Mesmo par gateway + evento_id duplicado é barrado.
    v_ok := false;
    begin
        insert into bloome.eventos_pagamento
            (gateway, evento_id, payload, assinatura_valida)
        values ('mercadopago', 'evt-t17-c', '{}'::jsonb, true);
    exception when unique_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'uq_eventos_gateway_id');
    end;
    if not v_ok then
        raise exception 'T17 FALHOU: evento duplicado no mesmo gateway foi aceito';
    end if;

    -- Nenhuma coluna de dado de cartão no schema.
    select count(*) into v_qtd
      from information_schema.columns
     where table_schema = 'bloome'
       and column_name ~ 'cartao|card|pan|cvv|cvc';
    if v_qtd <> 0 then
        raise exception 'T17 FALHOU: schema tem coluna de dado de cartao';
    end if;

    raise notice 'T17 OK: assinatura, gateways e ausencia de dado de cartao';
end $$;
rollback;


-- =====================================================================
-- T18 — produto removido, volta em breve e DELETE bloqueado
--        (EC-09/EC-10/EC-51)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t18', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t18', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t18', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T18', 'cliente.t18@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    -- Volta em breve também bloqueia a venda.
    update bloome.acessorios set status = 'volta_em_breve' where id_acessorios = v_modelo;

    begin
        insert into bloome.itens_pedidos
            (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
        values (v_ped, v_var, 1, 0, 0);
    exception when others then
        if sqlerrm like '%produto_indisponivel%' then
            v_ok := true;
        else
            raise exception 'T18 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T18 FALHOU: modelo volta_em_breve vendeu';
    end if;

    -- Removido também.
    v_ok := false;
    update bloome.acessorios set status = 'removido' where id_acessorios = v_modelo;

    begin
        insert into bloome.itens_pedidos
            (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
        values (v_ped, v_var, 1, 0, 0);
    exception when others then
        if sqlerrm like '%produto_indisponivel%' then
            v_ok := true;
        else
            raise exception 'T18 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T18 FALHOU: modelo removido vendeu';
    end if;

    -- Sem DELETE físico de produto.
    v_ok := false;
    begin
        delete from bloome.acessorios where id_acessorios = v_modelo;
    exception when others then
        if sqlerrm like '%delete_fisico_proibido%' then
            v_ok := true;
        else
            raise exception 'T18 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T18 FALHOU: produto foi apagado';
    end if;

    -- Sem DELETE físico de cliente.
    v_ok := false;
    begin
        delete from bloome.clientes where id_cliente = v_cli;
    exception when others then
        if sqlerrm like '%delete_fisico_proibido%' then
            v_ok := true;
        else
            raise exception 'T18 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T18 FALHOU: cliente foi apagado';
    end if;

    raise notice 'T18 OK: removido/volta em breve nao vendem; DELETE bloqueado';
end $$;
rollback;


-- =====================================================================
-- T19 — cor esgotada derivada do estoque (EC-12/EC-15/EC-20)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_produzivel integer;
    v_disponivel boolean;
    v_status_manual text;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t19', 2.00, 2, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t19', 4.00, 5, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t19', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    select produzivel, disponivel, status_manual
      into v_produzivel, v_disponivel, v_status_manual
      from bloome.vw_variacoes_disponiveis
     where id_variacao = v_var;

    if v_produzivel <> 2 or v_disponivel is not true then
        raise exception 'T19 FALHOU: com estoque, produzivel=% disponivel=%',
            v_produzivel, v_disponivel;
    end if;

    -- Zera o gargalo: a cor desaparece da venda, mas continua na view.
    update bloome.insumos set quantidade_estoque = 0 where id_insumos = v_fio;

    select produzivel, disponivel
      into v_produzivel, v_disponivel
      from bloome.vw_variacoes_disponiveis
     where id_variacao = v_var;

    if v_produzivel <> 0 or v_disponivel is not false then
        raise exception 'T19 FALHOU: sem estoque, produzivel=% disponivel=%',
            v_produzivel, v_disponivel;
    end if;

    -- Bloqueio manual também desabilita, mesmo com saldo.
    update bloome.insumos set quantidade_estoque = 5 where id_insumos = v_fio;
    update bloome.variacoes set status = 'esgotado' where id_variacao = v_var;

    select disponivel into v_disponivel
      from bloome.vw_variacoes_disponiveis
     where id_variacao = v_var;

    if v_disponivel is not false then
        raise exception 'T19 FALHOU: cor bloqueada manualmente apareceu disponivel';
    end if;

    raise notice 'T19 OK: esgotado derivado do estoque e do bloqueio manual';
end $$;
rollback;


-- =====================================================================
-- T20 — catálogo: sem pingente, pingente sem saldo e sem cor vendável
--        (EC-10/EC-11)
-- =====================================================================
begin;
do $$
declare
    v_ping_ok integer;
    v_ping_zero integer;
    v_fio_zero integer;
    v_modelo_a integer;
    v_modelo_b integer;
    v_modelo_c integer;
    v_modelo_d integer;
    v_modelo_e integer;
    v_var integer;
    v_status text;
    v_motivo text;
    v_tem_removido boolean;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t20-ok', 4.00, 5, 'pingente')
    returning id_insumos into v_ping_ok;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t20-zero', 4.00, 0, 'pingente')
    returning id_insumos into v_ping_zero;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t20-zero', 2.00, 0, 'fio')
    returning id_insumos into v_fio_zero;

    -- A: sem pingente cadastrado.
    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t20-a', 'cordao', 20.00, null)
    returning id_acessorios into v_modelo_a;

    -- B: pingente cadastrado e sem saldo.
    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t20-b', 'cordao', 20.00, v_ping_zero)
    returning id_acessorios into v_modelo_b;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo_b, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_ping_zero, 1);

    -- C: pingente ok, mas a receita depende de insumo zerado.
    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t20-c', 'cordao', 20.00, v_ping_ok)
    returning id_acessorios into v_modelo_c;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo_c, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_ping_ok, 1), (v_var, v_fio_zero, 1);

    -- D: saudável.
    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t20-d', 'cordao', 20.00, v_ping_ok)
    returning id_acessorios into v_modelo_d;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo_d, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_ping_ok, 1);

    -- E: removido não aparece.
    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario,
         pingente_insumo_id, status)
    values ('modelo-t20-e', 'cordao', 20.00, v_ping_ok, 'removido')
    returning id_acessorios into v_modelo_e;

    select status_exibicao, motivo_indisponibilidade
      into v_status, v_motivo
      from bloome.vw_catalogo_publico where id_acessorios = v_modelo_a;
    if v_status <> 'volta_em_breve' or v_motivo <> 'sem_pingente' then
        raise exception 'T20 FALHOU: A = % / %', v_status, v_motivo;
    end if;

    select status_exibicao, motivo_indisponibilidade
      into v_status, v_motivo
      from bloome.vw_catalogo_publico where id_acessorios = v_modelo_b;
    if v_status <> 'volta_em_breve' or v_motivo <> 'pingente_sem_estoque' then
        raise exception 'T20 FALHOU: B = % / %', v_status, v_motivo;
    end if;

    select status_exibicao, motivo_indisponibilidade
      into v_status, v_motivo
      from bloome.vw_catalogo_publico where id_acessorios = v_modelo_c;
    if v_status <> 'volta_em_breve' or v_motivo <> 'sem_cor_vendavel' then
        raise exception 'T20 FALHOU: C = % / %', v_status, v_motivo;
    end if;

    select status_exibicao, motivo_indisponibilidade
      into v_status, v_motivo
      from bloome.vw_catalogo_publico where id_acessorios = v_modelo_d;
    if v_status <> 'ativo' or v_motivo is not null then
        raise exception 'T20 FALHOU: D = % / %', v_status, v_motivo;
    end if;

    select exists (
        select 1 from bloome.vw_catalogo_publico where id_acessorios = v_modelo_e
    ) into v_tem_removido;
    if v_tem_removido then
        raise exception 'T20 FALHOU: modelo removido apareceu no catalogo';
    end if;

    raise notice 'T20 OK: catalogo deriva volta_em_breve e esconde removidos';
end $$;
rollback;


-- =====================================================================
-- T21 — cancelar sem baixa e cancelamento duplicado (EC-06/EC-42)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_res text;
    v_qtd numeric(12,3);
    v_motivo text;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t21', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t21', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t21', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T21', 'cliente.t21@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    -- Nunca pagou: nada a devolver; motivo vazio cai no padrão.
    v_res := bloome.cancelar_pedido(v_ped, '');
    if v_res <> 'sem_baixa' then
        raise exception 'T21 FALHOU: cancelamento = % (esperava sem_baixa)', v_res;
    end if;

    select motivo_cancelamento into v_motivo
      from bloome.pedidos where id_pedidos = v_ped;
    if v_motivo is null or btrim(v_motivo) = '' then
        raise exception 'T21 FALHOU: motivo padrao nao foi gravado';
    end if;

    select quantidade_estoque into v_qtd from bloome.insumos where id_insumos = v_fio;
    if v_qtd <> 10 then
        raise exception 'T21 FALHOU: estoque mudou sem baixa: %', v_qtd;
    end if;

    -- Cancelar de novo não pode.
    begin
        perform bloome.cancelar_pedido(v_ped, 'de novo');
    exception when others then
        if sqlerrm like '%transicao_invalida%' then
            v_ok := true;
        else
            raise exception 'T21 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T21 FALHOU: cancelamento duplicado foi aceito';
    end if;

    raise notice 'T21 OK: cancelar sem baixa nao mexe no estoque; duplicado recusado';
end $$;
rollback;


-- =====================================================================
-- T22 — preço/custo são snapshot do checkout (EC-38)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_item integer;
    v_preco numeric(10,2);
    v_custo numeric(10,2);
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t22', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t22', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t22', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T22', 'cliente.t22@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0)
    returning id_item into v_item;

    select preco_unitario, custo_unitario into v_preco, v_custo
      from bloome.itens_pedidos where id_item = v_item;
    if v_preco <> 20.00 or v_custo <> 6.00 then
        raise exception 'T22 FALHOU: snapshot inicial %, %', v_preco, v_custo;
    end if;

    -- Muda preço do modelo e custo dos insumos: o item antigo não muda.
    update bloome.acessorios set valor_acessorario = 30.00 where id_acessorios = v_modelo;
    update bloome.insumos set valor_unitario = 5.00 where id_insumos = v_fio;

    select preco_unitario, custo_unitario into v_preco, v_custo
      from bloome.itens_pedidos where id_item = v_item;
    if v_preco <> 20.00 or v_custo <> 6.00 then
        raise exception 'T22 FALHOU: snapshot mudou depois (%, %)', v_preco, v_custo;
    end if;

    -- Item novo já entra com os valores de hoje.
    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0)
    returning id_item into v_item;

    select preco_unitario, custo_unitario into v_preco, v_custo
      from bloome.itens_pedidos where id_item = v_item;
    if v_preco <> 30.00 or v_custo <> 9.00 then
        raise exception 'T22 FALHOU: item novo com valor errado (%, %)', v_preco, v_custo;
    end if;

    -- Alterar o snapshot do item à mão é proibido.
    begin
        update bloome.itens_pedidos set preco_unitario = 1.00
         where id_item = v_item;
    exception when others then
        if sqlerrm like '%snapshot_imutavel%' then
            v_ok := true;
        else
            raise exception 'T22 FALHOU: excecao inesperada: %', sqlerrm;
        end if;
    end;
    if not v_ok then
        raise exception 'T22 FALHOU: preco do item foi adulterado';
    end if;

    raise notice 'T22 OK: preco/custo congelados por item';
end $$;
rollback;


-- =====================================================================
-- T23 — estoque nunca fica negativo (EC-40)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_constraint text;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t23', 2.00, 1, 'fio')
    returning id_insumos into v_fio;

    begin
        update bloome.insumos set quantidade_estoque = -1
         where id_insumos = v_fio;
    exception when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'ck_insumos_estoque');
    end;
    if not v_ok then
        raise exception 'T23 FALHOU: estoque negativo foi aceito';
    end if;

    raise notice 'T23 OK: CHECK impede estoque negativo';
end $$;
rollback;


-- =====================================================================
-- T24 — LGPD: anonimizar sem apagar o histórico (EC-51)
-- =====================================================================
begin;
do $$
declare
    v_cli integer;
    v_ped integer;
    v_nome text;
    v_email text;
    v_anon timestamptz;
    v_pedidos integer;
begin
    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T24', 'cliente.t24@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    perform bloome.anonimizar_cliente(v_cli);

    select nome, email, anonimizado_em
      into v_nome, v_email, v_anon
      from bloome.clientes where id_cliente = v_cli;

    if v_nome <> 'Cliente anonimizado' then
        raise exception 'T24 FALHOU: nome nao foi anonimizado';
    end if;
    if v_email not like 'anon-%@invalid.local' then
        raise exception 'T24 FALHOU: e-mail nao foi anonimizado: %', v_email;
    end if;
    if v_anon is null then
        raise exception 'T24 FALHOU: anonimizado_em nao foi marcado';
    end if;

    select count(*) into v_pedidos from bloome.pedidos where id_cliente = v_cli;
    if v_pedidos <> 1 then
        raise exception 'T24 FALHOU: historico de pedidos foi perdido';
    end if;

    -- O e-mail original fica livre para um novo cadastro.
    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente novo', 'cliente.t24@teste.local', repeat('y', 60));

    raise notice 'T24 OK: anonimizacao preservou pedidos e liberou o e-mail';
end $$;
rollback;


-- =====================================================================
-- T25 — código público e precisão de data/hora (EC-34/EC-35)
-- =====================================================================
begin;
do $$
declare
    v_cli integer;
    v_ped_a integer;
    v_ped_b integer;
    v_codigo_a text;
    v_codigo_b text;
    v_tipo text;
    v_ok boolean;
begin
    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T25', 'cliente.t25@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos, codigo into v_ped_a, v_codigo_a;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos, codigo into v_ped_b, v_codigo_b;

    if v_codigo_a !~ '^#BLO-[0-9]{4,}$' or v_codigo_b !~ '^#BLO-[0-9]{4,}$' then
        raise exception 'T25 FALHOU: formato de codigo invalido: %, %', v_codigo_a, v_codigo_b;
    end if;

    if v_codigo_a = v_codigo_b then
        raise exception 'T25 FALHOU: dois pedidos com o mesmo codigo';
    end if;

    select data_type into v_tipo
      from information_schema.columns
     where table_schema = 'bloome'
       and table_name = 'pedidos'
       and column_name = 'criado_em';

    if v_tipo <> 'timestamp with time zone' then
        raise exception 'T25 FALHOU: criado_em e % (esperava timestamptz)', v_tipo;
    end if;

    select (count(*) = 2 and count(distinct codigo) = 2)
      into v_ok
      from bloome.pedidos
     where id_cliente = v_cli;

    if not v_ok then
        raise exception 'T25 FALHOU: codigos dos pedidos nao sao unicos';
    end if;

    raise notice 'T25 OK: codigo sequencial unico e criado_em com fuso';
end $$;
rollback;


-- =====================================================================
-- T26 — alerta de estoque no mínimo (EC-13)
-- =====================================================================
begin;
do $$
declare
    v_nao_alerta integer;
    v_critico integer;
    v_zerado integer;
    v_deficit numeric;
    v_nivel text;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('insumo-t26-fora', 1.00, 6, 'fio')
    returning id_insumos into v_nao_alerta;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('insumo-t26-critico', 1.00, 5, 'fio');

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('insumo-t26-zero', 1.00, 0, 'fio');

    if exists (
        select 1 from bloome.vw_alerta_estoque where id_insumos = v_nao_alerta
    ) then
        raise exception 'T26 FALHOU: insumo acima do minimo apareceu no alerta';
    end if;

    select deficit, nivel into v_deficit, v_nivel
      from bloome.vw_alerta_estoque
     where nome = 'insumo-t26-critico';
    if v_nivel <> 'critico' or v_deficit <> 0 then
        raise exception 'T26 FALHOU: critico = %, %', v_nivel, v_deficit;
    end if;

    select deficit, nivel into v_deficit, v_nivel
      from bloome.vw_alerta_estoque
     where nome = 'insumo-t26-zero';
    if v_nivel <> 'zerado' or v_deficit <> 5 then
        raise exception 'T26 FALHOU: zerado = %, %', v_nivel, v_deficit;
    end if;

    raise notice 'T26 OK: alerta dispara em saldo igual ou abaixo do minimo';
end $$;
rollback;


-- =====================================================================
-- T27 — insumo usado em receita não pode ser apagado (EC-16)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_constraint text;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t27', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t27', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t27', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    begin
        delete from bloome.insumos where id_insumos = v_fio;
    exception when foreign_key_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'fk_composicao_insumo');
    end;
    if not v_ok then
        raise exception 'T27 FALHOU: insumo da receita foi apagado';
    end if;

    -- O pingente é referenciado pelo modelo; apagar também é bloqueado.
    v_ok := false;
    begin
        delete from bloome.insumos where id_insumos = v_ping;
    exception when foreign_key_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint in ('fk_acessorios_pingente', 'fk_composicao_insumo'));
    end;
    if not v_ok then
        raise exception 'T27 FALHOU: pingente do modelo foi apagado';
    end if;

    raise notice 'T27 OK: FK RESTRICT protege a receita e o pingente';
end $$;
rollback;


-- =====================================================================
-- T28 — variação com histórico de pedido não pode ser apagada (EC-17)
-- =====================================================================
begin;
do $$
declare
    v_fio integer;
    v_ping integer;
    v_modelo integer;
    v_var integer;
    v_cli integer;
    v_ped integer;
    v_constraint text;
    v_ok boolean := false;
begin
    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('fio-t28', 2.00, 10, 'fio')
    returning id_insumos into v_fio;

    insert into bloome.insumos (nome, valor_unitario, quantidade_estoque, categoria)
    values ('pingente-t28', 4.00, 10, 'pingente')
    returning id_insumos into v_ping;

    insert into bloome.acessorios
        (nome_acessorios, categoria_acessorio, valor_acessorario, pingente_insumo_id)
    values ('modelo-t28', 'cordao', 20.00, v_ping)
    returning id_acessorios into v_modelo;

    insert into bloome.variacoes (id_acessorios, cor, cor_hex)
    values (v_modelo, 'preto', '#000000')
    returning id_variacao into v_var;

    insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
    values (v_var, v_fio, 1), (v_var, v_ping, 1);

    insert into bloome.clientes (nome, email, senha_hash)
    values ('Cliente T28', 'cliente.t28@teste.local', repeat('x', 60))
    returning id_cliente into v_cli;

    insert into bloome.pedidos (id_cliente, frete_pago_por, metodo_pagamento, tipo_entrega)
    values (v_cli, 'loja', 'pix', 'retirada')
    returning id_pedidos into v_ped;

    insert into bloome.itens_pedidos
        (id_pedidos, id_variacao, quantidade, preco_unitario, custo_unitario)
    values (v_ped, v_var, 1, 0, 0);

    -- Remove a receita para isolar o que deve barrar: o histórico de venda.
    delete from bloome.composicao_variacoes where id_variacao = v_var;

    begin
        delete from bloome.variacoes where id_variacao = v_var;
    exception when foreign_key_violation then
        get stacked diagnostics v_constraint = constraint_name;
        v_ok := (v_constraint = 'fk_itens_variacao');
    end;
    if not v_ok then
        raise exception 'T28 FALHOU: variacao com historico foi apagada';
    end if;

    raise notice 'T28 OK: FK RESTRICT preserva o historico de vendas';
end $$;
rollback;


-- =====================================================================
-- FIM — todos os blocos terminaram em ROLLBACK; nada foi gravado.
-- Um teste ausente (sem NOTICE T## OK) indica que o script parou antes;
-- o erro mostra qual.
-- =====================================================================
