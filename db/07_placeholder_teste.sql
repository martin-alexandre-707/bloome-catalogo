-- 07_placeholder_teste.sql
--
-- DADOS FICTÍCIOS PARA TESTE (ADR-017) — NÃO É DADO REAL.
-- Os valores (99, preços, quantidades de fio) são inventados só para o site
-- sair do "volta em breve". Quando os dados reais chegarem, rode o bloco
-- "PARA DESFAZER" do fim deste arquivo e cadastre de verdade.
--
-- Regra do teste (decisão do time em 2026-11-24):
--   * todos os insumos com saldo 99;
--   * 3 modelos ficam "em breve":
--       - 27 Chocker Fita Pura  -> sem pingente (regra D2, sempre em breve);
--       - 28 Cordão Gota        -> pingente com saldo 0;
--       - 37 Colar Peixe Colorido -> pingente com saldo 0.
--
-- Idempotente: INSERT ... ON CONFLICT DO NOTHING + UPDATE.
-- Rodar: python db/aplicar.py --teste

begin;

-- 1. Insumos (fios + pingentes). Preços fictícios.
insert into bloome.insumos
    (nome, valor_unitario, quantidade_estoque, categoria, unidade_medida, estoque_minimo)
values
    ('Fio camurça',          4.00, 99, 'Fio',      'm',  5),
    ('Fio courinho',         4.00, 99, 'Fio',      'm',  5),
    ('Fio courinho dourado', 5.00, 99, 'Fio',      'm',  5),
    ('Fio torcido',          4.50, 99, 'Fio',      'm',  5),
    ('Corrente',             6.00, 99, 'Fio',      'm',  5),
    ('Pingente coração',          3.50, 99, 'Pingente', 'un', 5),
    ('Pingente inicial',          3.50, 99, 'Pingente', 'un', 5),
    ('Pingente gota',             3.50,  0, 'Pingente', 'un', 5),
    ('Pingente São Bento',        3.50, 99, 'Pingente', 'un', 5),
    ('Pingente olho grego',       3.50, 99, 'Pingente', 'un', 5),
    ('Pingente espinha',          3.50, 99, 'Pingente', 'un', 5),
    ('Pingente arco médio',       3.50, 99, 'Pingente', 'un', 5),
    ('Pingente peixe torcido',    3.50, 99, 'Pingente', 'un', 5),
    ('Aplicação strass',          2.00, 99, 'Pingente', 'un', 5),
    ('Pingente arco especial',    3.50, 99, 'Pingente', 'un', 5),
    ('Pingente sol',              3.50, 99, 'Pingente', 'un', 5),
    ('Pingente peixe colorido',   3.50, 99, 'Pingente', 'un', 5),
    ('Pingente estrela do mar',   3.50, 99, 'Pingente', 'un', 5),
    ('Pingente concha e pérola',  4.00, 99, 'Pingente', 'un', 5)
on conflict (lower(btrim(nome))) do nothing;

-- Garante o cenário de teste mesmo se o arquivo rodar de novo.
update bloome.insumos
set quantidade_estoque = case when nome = 'Pingente gota' then 0 else 99 end
where nome in ('Pingente gota', 'Pingente peixe colorido');

-- 2. Pingente de cada modelo (27 fica NULL de propósito).
update bloome.acessorios as a
set pingente_insumo_id = i.id_insumos
from (values
    (24, 'Pingente coração'),
    (25, 'Pingente inicial'),
    (28, 'Pingente gota'),
    (29, 'Pingente São Bento'),
    (30, 'Pingente olho grego'),
    (31, 'Pingente espinha'),
    (32, 'Pingente arco médio'),
    (33, 'Pingente peixe torcido'),
    (34, 'Aplicação strass'),
    (35, 'Pingente arco especial'),
    (36, 'Pingente sol'),
    (37, 'Pingente peixe colorido'),
    (38, 'Pingente estrela do mar'),
    (39, 'Pingente concha e pérola')
) as d(id_acessorios, nome_insumo)
join bloome.insumos i on lower(btrim(i.nome)) = lower(btrim(d.nome_insumo))
where a.id_acessorios = d.id_acessorios;

-- 3. Receita de fio em todas as variações (mesma receita por modelo).
insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
select
    v.id_variacao,
    f.id_insumos,
    case when a.categoria_acessorio = 'Chocker' then 0.35 else 0.50 end
from bloome.variacoes v
join bloome.acessorios a on a.id_acessorios = v.id_acessorios
join bloome.insumos f on lower(btrim(f.nome)) = lower(btrim(
    case a.material
        when 'Camurça'          then 'Fio camurça'
        when 'Courinho'         then 'Fio courinho'
        when 'Courinho Dourado' then 'Fio courinho dourado'
        when 'Fio Torcido'      then 'Fio torcido'
        when 'Corrente'         then 'Corrente'
    end
))
on conflict (id_variacao, id_insumos) do nothing;

-- 4. Receita de pingente (1 por peça), onde o modelo tem pingente.
insert into bloome.composicao_variacoes (id_variacao, id_insumos, quantidade)
select v.id_variacao, a.pingente_insumo_id, 1
from bloome.variacoes v
join bloome.acessorios a on a.id_acessorios = v.id_acessorios
where a.pingente_insumo_id is not null
on conflict (id_variacao, id_insumos) do nothing;

commit;

-- =====================================================================
-- PARA DESFAZER (quando os dados reais chegarem):
--
-- begin;
--   delete from bloome.composicao_variacoes;
--   update bloome.acessorios set pingente_insumo_id = null;
--   delete from bloome.insumos;
-- commit;
-- =====================================================================
