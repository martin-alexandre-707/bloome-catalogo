-- =====================================================================
-- Bloome — 05_queries.sql
--
-- Papel no sistema: consultas de conferência e de uso diário do /adm.
-- SOMENTE LEITURA: nada aqui cria, altera ou apaga.
--
-- Rode no SQL Editor do Supabase depois de 04_seed.sql.
-- Cada bloco traz, no comentário, o resultado esperado hoje.
-- =====================================================================


-- =====================================================================
-- 1. O seed entrou certo?
-- Esperado: 16 produtos, 49 variações, menor 18.00, maior 50.00.
-- =====================================================================
select
    (select count(*) from bloome.acessorios where status <> 'removido')
        as produtos,
    (select count(*) from bloome.variacoes)
        as variacoes,
    (select min(valor_acessorario) from bloome.acessorios where status <> 'removido')
        as menor_preco,
    (select max(valor_acessorario) from bloome.acessorios where status <> 'removido')
        as maior_preco;


-- =====================================================================
-- 2. Vitrine como o cliente vê
-- Esperado: 16 linhas; todas 'volta_em_breve' com motivo 'sem_pingente'
-- enquanto o pingente de cada modelo não for cadastrado (EC-10).
-- =====================================================================
select
    categoria_acessorio,
    nome_acessorios,
    valor_acessorario,
    material,
    status_exibicao,
    motivo_indisponibilidade,
    cores_total,
    cores_disponiveis
from bloome.vw_catalogo_publico
order by categoria_acessorio, nome_acessorios;


-- =====================================================================
-- 3. Cores de cada modelo e quanto dá para produzir agora
-- Esperado hoje: 49 linhas, todas receita_completa = false,
-- produzivel = 0 e disponivel = false (falta cadastrar a receita).
-- =====================================================================
select
    nome_acessorios,
    cor,
    cor_hex,
    status_manual,
    receita_completa,
    produzivel,
    disponivel
from bloome.vw_variacoes_disponiveis
order by nome_acessorios, ordem, cor;


-- =====================================================================
-- 4. Bolinhas cinza/opacas (cor esgotada) — continuam visíveis (EC-12)
-- Esperado hoje: as 49 cores, porque nenhuma tem receita ainda.
-- =====================================================================
select
    nome_acessorios,
    cor,
    status_manual,
    receita_completa,
    produzivel
from bloome.vw_variacoes_disponiveis
where disponivel = false
order by nome_acessorios, ordem, cor;


-- =====================================================================
-- 5. Material acabando (EC-13)
-- Esperado: vazio hoje (sem insumos). Depois: saldo <= minimo.
-- =====================================================================
select
    nome,
    categoria,
    quantidade_estoque,
    estoque_minimo,
    deficit,
    nivel
from bloome.vw_alerta_estoque
order by nivel desc, deficit desc, nome;


-- =====================================================================
-- 6. Fila de produção — o que a dona precisa montar
-- Esperado: vazio hoje. Depois: pedidos pago/em_producao, mais antigo
-- primeiro, com a lista de itens e o consumo de insumos em JSON.
-- =====================================================================
select
    codigo,
    status,
    tipo_entrega,
    idade_dias,
    total_itens,
    total_pecas,
    itens,
    consumo
from bloome.vw_fila_producao
order by criado_em;


-- =====================================================================
-- 7. Pedidos, custo e lucro
-- Esperado: vazio hoje. Lucro = subtotal - custo (frete não é receita).
-- Pedido cancelado aparece com status 'cancelado' e deve ser filtrado
-- nos relatórios.
-- =====================================================================
select
    codigo,
    cliente,
    status,
    metodo_pagamento,
    subtotal,
    frete_valor,
    valor_total,
    custo_total,
    lucro,
    margem_percentual,
    criado_em
from bloome.vw_resumo_pedidos
order by criado_em desc
limit 20;


-- =====================================================================
-- 8. Faturamento e lucro por mês (sem cancelados)
-- Esperado: vazio hoje.
-- =====================================================================
select
    date_trunc('month', criado_em)::date          as mes,
    count(*)                                      as pedidos,
    sum(subtotal)                                 as faturamento,
    sum(custo_total)                              as custo,
    sum(lucro)                                    as lucro
from bloome.vw_resumo_pedidos
where status <> 'cancelado'
group by 1
order by 1 desc;


-- =====================================================================
-- 9. O que falta para cada modelo ficar vendável
-- Esperado hoje: falta_cor = false (49 cores cadastradas), mas
-- falta_pingente, falta_receita, falta_foto e falta_descricao = true.
-- É a lista de trabalho do /adm.
-- =====================================================================
select
    a.nome_acessorios,
    (a.pingente_insumo_id is null)                    as falta_pingente,
    (a.foto is null)                                  as falta_foto,
    (a.descricao is null)                             as falta_descricao,
    not exists (
        select 1 from bloome.variacoes v
         where v.id_acessorios = a.id_acessorios
    )                                                 as falta_cor,
    not exists (
        select 1
          from bloome.variacoes v
          join bloome.composicao_variacoes cv on cv.id_variacao = v.id_variacao
         where v.id_acessorios = a.id_acessorios
    )                                                 as falta_receita
from bloome.acessorios a
where a.status <> 'removido'
order by a.nome_acessorios;


-- =====================================================================
-- 10. Webhooks pendentes ou com erro
-- Esperado: vazio hoje. Depois do gateway: eventos que não foram
-- processados (aguardando pedido, erro, rejeitado).
-- =====================================================================
select
    gateway,
    evento_id,
    id_pedidos,
    status_evento,
    assinatura_valida,
    tentativas,
    recebido_em,
    processado_em
from bloome.eventos_pagamento
where status_evento not in ('processado', 'ignorado')
order by recebido_em;
