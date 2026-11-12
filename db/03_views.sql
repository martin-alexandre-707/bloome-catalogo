-- =====================================================================
-- Bloome — 03_views.sql
--
-- Papel no sistema: transformar as regras de catálogo, estoque e dinheiro
-- em consultas prontas. View NÃO guarda dado: é a leitura oficial do banco,
-- usada pelo site e pelo /adm. Nada aqui altera dado (somente leitura).
--
-- Pré-requisito: 01_schema.sql e 02_funcoes.sql já aplicados.
-- `with (security_invoker = true)` exige PostgreSQL 15+ (Supabase).
--
-- Views e quem usa:
--   vw_variacoes_disponiveis -> site (bolinha de cor) e /adm
--   vw_catalogo_publico      -> vitrine e /adm
--   vw_alerta_estoque        -> /adm (material acabando)
--   vw_fila_producao         -> /adm (o que produzir)
--   vw_resumo_pedidos        -> /adm (pedidos, custo e lucro)
-- =====================================================================

begin;

-- =====================================================================
-- 1. DISPONIBILIDADE POR COR (EC-12/EC-20)
--
-- A cor não tem coluna "esgotado" calculada: o status exibido vem daqui.
-- `produzivel` = quantas peças a receita daquela cor permite montar agora
--                com o saldo atual dos insumos. O gargalo é o insumo que
--                acaba primeiro, por isso o MIN.
-- `disponivel` = receita cadastrada + cor não bloqueada + dá para 1 peça.
--
-- Receita vazia => produzivel 0 e receita_completa false.
-- O pingente do modelo NÃO é tratado aqui: é regra do modelo, aplicada em
-- vw_catalogo_publico (D2). Quando ele está na receita, entra no MIN.
-- =====================================================================

create or replace view bloome.vw_variacoes_disponiveis
with (security_invoker = true) as
select
    d.*,
    (d.receita_completa and d.status_manual = 'ativo' and d.produzivel >= 1)
        as disponivel
from (
    select
        v.id_variacao,
        v.id_acessorios,
        a.nome_acessorios,
        v.cor,
        v.cor_hex,
        v.ordem,
        v.status                                                  as status_manual,
        count(cv.id_insumos)::int                                 as insumos_na_receita,
        (count(cv.id_insumos) > 0)                                as receita_completa,
        coalesce(min(floor(i.quantidade_estoque / cv.quantidade)), 0)::int
                                                                  as produzivel
    from bloome.variacoes v
    join bloome.acessorios a
      on a.id_acessorios = v.id_acessorios
    left join bloome.composicao_variacoes cv
      on cv.id_variacao = v.id_variacao
    left join bloome.insumos i
      on i.id_insumos = cv.id_insumos
    group by v.id_variacao, v.id_acessorios, a.nome_acessorios,
             v.cor, v.cor_hex, v.ordem, v.status
) d;

-- =====================================================================
-- 2. CATÁLOGO PÚBLICO (EC-09/EC-10/EC-11)
--
-- Um registro por modelo. `removido` nunca aparece (EC-09).
--
-- status_exibicao = 'volta_em_breve' quando:
--   - a dona marcou o modelo como volta_em_breve, ou
--   - o modelo não tem pingente cadastrado (pingente_insumo_id NULL), ou
--   - o pingente do modelo está sem saldo, ou
--   - nenhuma cor está vendável (D3).
-- Fora disso, 'ativo'.
--
-- motivo_indisponibilidade explica o porquê para o /adm:
--   'status_manual' | 'sem_pingente' | 'pingente_sem_estoque' |
--   'sem_cor_vendavel' | NULL (quando ativo).
--
-- Cor esgotada continua listada em vw_variacoes_disponiveis com
-- `disponivel = false` (bolinha cinza/opaca) — EC-12.
-- =====================================================================

create or replace view bloome.vw_catalogo_publico
with (security_invoker = true) as
select
    a.id_acessorios,
    a.nome_acessorios,
    a.categoria_acessorio,
    a.material,
    a.foto,
    a.descricao,
    a.valor_acessorario,
    a.status                                          as status_manual,
    case
        when a.status = 'volta_em_breve'              then 'volta_em_breve'
        when a.pingente_insumo_id is null             then 'volta_em_breve'
        when pi.quantidade_estoque is null
          or pi.quantidade_estoque <= 0               then 'volta_em_breve'
        when coalesce(cv.cores_disponiveis, 0) = 0    then 'volta_em_breve'
        else 'ativo'
    end                                               as status_exibicao,
    case
        when a.status = 'volta_em_breve'              then 'status_manual'
        when a.pingente_insumo_id is null             then 'sem_pingente'
        when pi.quantidade_estoque is null
          or pi.quantidade_estoque <= 0               then 'pingente_sem_estoque'
        when coalesce(cv.cores_disponiveis, 0) = 0    then 'sem_cor_vendavel'
        else null
    end                                               as motivo_indisponibilidade,
    coalesce(cv.cores_total, 0)                       as cores_total,
    coalesce(cv.cores_disponiveis, 0)                 as cores_disponiveis
from bloome.acessorios a
left join bloome.insumos pi
  on pi.id_insumos = a.pingente_insumo_id
left join (
    select
        v.id_acessorios,
        count(*)::int                                 as cores_total,
        (count(*) filter (where v.disponivel))::int   as cores_disponiveis
    from bloome.vw_variacoes_disponiveis v
    group by v.id_acessorios
) cv on cv.id_acessorios = a.id_acessorios
where a.status <> 'removido';

-- =====================================================================
-- 3. ALERTA DE ESTOQUE (EC-13)
--
-- Insumo entra quando o saldo chega ao mínimo (padrão 5, ajustável por
-- insumo). `nivel`: 'zerado' (saldo <= 0) ou 'critico' (saldo entre 1 e
-- o mínimo). `deficit` = quanto falta para voltar ao mínimo.
-- =====================================================================

create or replace view bloome.vw_alerta_estoque
with (security_invoker = true) as
select
    i.id_insumos,
    i.nome,
    i.categoria,
    i.unidade_medida,
    i.quantidade_estoque,
    i.estoque_minimo,
    (i.estoque_minimo - i.quantidade_estoque)         as deficit,
    case
        when i.quantidade_estoque <= 0 then 'zerado'
        else 'critico'
    end                                               as nivel
from bloome.insumos i
where i.quantidade_estoque <= i.estoque_minimo
order by (i.quantidade_estoque <= 0) desc,
         (i.estoque_minimo - i.quantidade_estoque) desc,
         i.nome;

-- =====================================================================
-- 4. FILA DE PRODUÇÃO (EC-03/EC-06)
--
-- Pedidos pagos ou em produção, do mais antigo para o mais novo.
-- `itens` = lista JSON (modelo, cor, quantidade).
-- `consumo` = insumos que saíram do estoque, por id de insumo:
--   - usa `consumo_snapshot` (o que foi realmente baixado no pagamento);
--   - se o snapshot ainda não existir, cai para a receita atual.
-- Como o estoque é baixado só no pagamento, `pago` e `em_producao` já
-- estão sempre com estoque baixado (check EC-44).
-- =====================================================================

create or replace view bloome.vw_fila_producao
with (security_invoker = true) as
select
    p.id_pedidos,
    p.codigo,
    p.status,
    p.tipo_entrega,
    p.criado_em,
    (current_date - p.criado_em::date)::int           as idade_dias,
    iq.total_itens,
    iq.total_pecas,
    iq.detalhe                                        as itens,
    coalesce(p.consumo_snapshot, rq.consumo_receita)  as consumo,
    p.rastreio
from bloome.pedidos p
left join lateral (
    select
        count(*)::int                                 as total_itens,
        coalesce(sum(ip.quantidade), 0)::int          as total_pecas,
        jsonb_agg(jsonb_build_object(
            'id_variacao', ip.id_variacao,
            'modelo',      a.nome_acessorios,
            'cor',         v.cor,
            'quantidade',  ip.quantidade
        ) order by a.nome_acessorios, v.ordem, v.cor) as detalhe
    from bloome.itens_pedidos ip
    join bloome.variacoes v       on v.id_variacao = ip.id_variacao
    join bloome.acessorios a      on a.id_acessorios = v.id_acessorios
    where ip.id_pedidos = p.id_pedidos
) iq on true
left join lateral (
    select jsonb_object_agg(c.id_insumos::text, c.qtd) as consumo_receita
    from (
        select
            cv.id_insumos,
            sum(cv.quantidade * ip.quantidade)        as qtd
        from bloome.itens_pedidos ip
        join bloome.composicao_variacoes cv
          on cv.id_variacao = ip.id_variacao
        where ip.id_pedidos = p.id_pedidos
        group by cv.id_insumos
    ) c
) rq on true
where p.status in ('pago', 'em_producao')
order by p.criado_em;

-- =====================================================================
-- 5. RESUMO DE PEDIDOS (EC-28/EC-38)
--
-- Uma linha por pedido, com cliente, dinheiro e lucro.
-- `custo_total` usa o snapshot `custo_unitario` do item (o custo do dia
-- da venda, não o de hoje) — EC-38.
-- `lucro` = subtotal - custo. O frete fica de fora porque é pago pelo
-- cliente e repassado; não é receita da loja.
-- Pedido cancelado continua na view: relatórios filtram por `status`.
-- =====================================================================

create or replace view bloome.vw_resumo_pedidos
with (security_invoker = true) as
select
    p.id_pedidos,
    p.codigo,
    p.status,
    c.nome                                            as cliente,
    c.email                                           as cliente_email,
    p.tipo_entrega,
    p.metodo_pagamento,
    p.subtotal,
    p.frete_valor,
    p.valor_total,
    iq.total_itens,
    iq.total_pecas,
    iq.custo_total,
    round(p.subtotal - iq.custo_total, 2)             as lucro,
    case
        when p.subtotal > 0
        then round((p.subtotal - iq.custo_total) / p.subtotal * 100, 2)
        else null
    end                                               as margem_percentual,
    p.criado_em,
    p.rastreio,
    p.reembolsado_em,
    p.reembolso_valor
from bloome.pedidos p
join bloome.clientes c
  on c.id_cliente = p.id_cliente
cross join lateral (
    select
        count(*)::int                                 as total_itens,
        coalesce(sum(ip.quantidade), 0)::int          as total_pecas,
        coalesce(sum(ip.custo_unitario * ip.quantidade), 0)::numeric(10,2)
                                                      as custo_total
    from bloome.itens_pedidos ip
    where ip.id_pedidos = p.id_pedidos
) iq
order by p.criado_em desc;

commit;

-- =====================================================================
-- COBERTURA DAS EDGE CASES (matriz docs/PLANO-BANCO-BLOOME.md §7.1)
--   EC-02/03 ........ receita por variação; disponibilidade derivada
--   EC-09 ........... vw_catalogo_publico exclui `removido`
--   EC-10 ........... sem pingente cadastrado ou sem saldo -> volta_em_breve
--   EC-11 ........... nenhuma cor vendável -> volta_em_breve
--   EC-12/EC-20 ..... cor esgotada visível com `disponivel = false`
--   EC-13 ........... vw_alerta_estoque (padrão <= 5)
--   EC-28/EC-38 ..... custo e lucro pelo snapshot do item
--   EC-44 ........... fila só de pedidos com estoque baixado
--
-- Views são leitura: não substituem os triggers de 02_funcoes.sql.
-- Todas usam security_invoker (não vazam dado para quem não tem SELECT).
-- =====================================================================
