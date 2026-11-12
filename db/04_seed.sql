-- =====================================================================
-- Bloome — 04_seed.sql
--
-- Papel no sistema: cadastrar o catálogo REAL da Bloome (16 modelos) para
-- o /adm começar a trabalhar. Não cria cor, receita, insumo nem pingente:
-- esses dados não existem na fonte e não podem ser inventados.
--
-- Fonte: docs/referencias/Catalogo-BLOOME.pdf (páginas 2, 3, 4 e 6).
-- Data da extração: 2026-11-12. Preços e materiais conferidos na
-- renderização visual das páginas (o texto do PDF embaralha a ordem).
--
-- Idempotente: reexecutar não duplica (unique funcional do nome).
-- Rode depois de 01_schema.sql; 02 e 03 não são pré-requisito, mas devem
-- estar aplicados antes de usar o site e o /adm.
--
-- O que entra:
--   * 16 produtos (nome, tipo, preço, material);
--   * 49 variações de cor — os nomes e os hex são INFERIDOS das bolinhas
--     do PDF (paleta recorrente: preto, marrom, vinho, oliva, dourado).
--     Confirmar com a dona; trocar o nome depois não mexe no preço.
--
-- O que NÃO entra aqui (o /adm preenche):
--   * insumos (fios, pingentes, pedras) e saldo;
--   * receita de cada cor (insumo x quantidade);
--   * foto (MVP em static/imgs/), descrição e pingente de cada modelo.
-- Enquanto faltar pingente, o catálogo mostra todos como "volta em breve"
-- com motivo `sem_pingente` — é o comportamento correto (EC-10).
-- =====================================================================

begin;

-- =====================================================================
-- CATÁLOGO REAL — 16 modelos, preços de R$ 18 a R$ 50
-- `material` segue o PDF; `pingente_insumo_id` fica NULL até o cadastro.
-- =====================================================================

insert into bloome.acessorios
    (nome_acessorios, categoria_acessorio, valor_acessorario, material, status)
values
    -- página 2
    ('Cordão Coração',       'Cordão',  45.00, 'Courinho',        'ativo'),
    ('Colar Inicial',        'Colar',   35.00, 'Courinho',        'ativo'),
    ('Cordão Amarração',     'Cordão',  30.00, 'Camurça',         'ativo'),
    ('Chocker Fita Pura',    'Chocker', 18.00, 'Camurça',         'ativo'),

    -- página 3
    ('Cordão Gota',          'Cordão',  45.00, 'Courinho',        'ativo'),
    ('Colar São Bento',      'Colar',   30.00, 'Courinho',        'ativo'),
    ('Chocker Olho Grego',   'Chocker', 30.00, 'Courinho',        'ativo'),
    ('Cordão Espinha P',     'Cordão',  45.00, 'Courinho',        'ativo'),

    -- página 4
    ('Cordão Arco Médio',    'Cordão',  45.00, 'Courinho',        'ativo'),
    ('Colar Peixe Torcido',  'Colar',   50.00, 'Fio Torcido',     'ativo'),
    ('Chocker Fita Strass',  'Chocker', 20.00, 'Camurça',         'ativo'),
    ('Cordão Arco Especial', 'Cordão',  50.00, 'Courinho Dourado','ativo'),

    -- página 6
    ('Cordão Sol Médio',     'Cordão',  50.00, 'Courinho',        'ativo'),
    ('Colar Peixe Colorido', 'Colar',   50.00, 'Corrente',        'ativo'),
    ('Chocker Estrela do Mar','Chocker',30.00, 'Courinho',        'ativo'),
    ('Cordão Concha Pérola', 'Cordão',  45.00, 'Camurça',         'ativo')
on conflict (lower(btrim(nome_acessorios))) do nothing;

-- =====================================================================
-- CORES POR MODELO — 49 variações inferidas das bolinhas do PDF
--
-- Contagem por modelo (conferida visualmente em 2026-11-12):
--   Cordão Coração 4 ......... Colar Inicial 3
--   Cordão Amarração 3 ....... Chocker Fita Pura 3
--   Cordão Gota 4 ............ Colar São Bento 4
--   Chocker Olho Grego 4 ..... Cordão Espinha P 4
--   Cordão Arco Médio 4 ...... Colar Peixe Torcido 3
--   Chocker Fita Strass 2 .... Cordão Arco Especial 1
--   Cordão Sol Médio 3 ....... Colar Peixe Colorido 1
--   Chocker Estrela do Mar 3 . Cordão Concha Pérola 3
--   Total: 49 (bate com VALIDACAO-REGRAS §1).
--
-- Paleta recorrente e ordem fixa (a mesma sequência em todos os modelos):
--   preto 1 · marrom 2 · vinho 3 · oliva 4 · dourado 5
-- O hex foi aproximado das bolinhas do PDF; não é a cor exata do tecido.
-- A cor não muda o preço (VALIDACAO-REGRAS §1).
--
-- Sem receita cadastrada, nenhuma cor fica vendável — o modelo continua
-- "volta em breve" mesmo com as cores presentes. É o esperado.
-- =====================================================================

insert into bloome.variacoes (id_acessorios, cor, cor_hex, ordem)
select a.id_acessorios, v.cor, v.cor_hex, v.ordem
from (values
    -- Cordão Coração (4)
    ('Cordão Coração',        'preto',   '#1A1A1A', 1),
    ('Cordão Coração',        'marrom',  '#4A2C1A', 2),
    ('Cordão Coração',        'vinho',   '#7A2230', 3),
    ('Cordão Coração',        'oliva',   '#6E7B4F', 4),

    -- Colar Inicial (3)
    ('Colar Inicial',         'preto',   '#1A1A1A', 1),
    ('Colar Inicial',         'marrom',  '#4A2C1A', 2),
    ('Colar Inicial',         'vinho',   '#7A2230', 3),

    -- Cordão Amarração (3)
    ('Cordão Amarração',      'preto',   '#1A1A1A', 1),
    ('Cordão Amarração',      'marrom',  '#4A2C1A', 2),
    ('Cordão Amarração',      'vinho',   '#7A2230', 3),

    -- Chocker Fita Pura (3)
    ('Chocker Fita Pura',     'preto',   '#1A1A1A', 1),
    ('Chocker Fita Pura',     'marrom',  '#4A2C1A', 2),
    ('Chocker Fita Pura',     'vinho',   '#7A2230', 3),

    -- Cordão Gota (4)
    ('Cordão Gota',           'preto',   '#1A1A1A', 1),
    ('Cordão Gota',           'marrom',  '#4A2C1A', 2),
    ('Cordão Gota',           'vinho',   '#7A2230', 3),
    ('Cordão Gota',           'oliva',   '#6E7B4F', 4),

    -- Colar São Bento (4)
    ('Colar São Bento',       'preto',   '#1A1A1A', 1),
    ('Colar São Bento',       'marrom',  '#4A2C1A', 2),
    ('Colar São Bento',       'vinho',   '#7A2230', 3),
    ('Colar São Bento',       'oliva',   '#6E7B4F', 4),

    -- Chocker Olho Grego (4)
    ('Chocker Olho Grego',    'preto',   '#1A1A1A', 1),
    ('Chocker Olho Grego',    'marrom',  '#4A2C1A', 2),
    ('Chocker Olho Grego',    'vinho',   '#7A2230', 3),
    ('Chocker Olho Grego',    'oliva',   '#6E7B4F', 4),

    -- Cordão Espinha P (4)
    ('Cordão Espinha P',      'preto',   '#1A1A1A', 1),
    ('Cordão Espinha P',      'marrom',  '#4A2C1A', 2),
    ('Cordão Espinha P',      'vinho',   '#7A2230', 3),
    ('Cordão Espinha P',      'oliva',   '#6E7B4F', 4),

    -- Cordão Arco Médio (4)
    ('Cordão Arco Médio',     'preto',   '#1A1A1A', 1),
    ('Cordão Arco Médio',     'marrom',  '#4A2C1A', 2),
    ('Cordão Arco Médio',     'vinho',   '#7A2230', 3),
    ('Cordão Arco Médio',     'oliva',   '#6E7B4F', 4),

    -- Colar Peixe Torcido (3)
    ('Colar Peixe Torcido',   'preto',   '#1A1A1A', 1),
    ('Colar Peixe Torcido',   'marrom',  '#4A2C1A', 2),
    ('Colar Peixe Torcido',   'vinho',   '#7A2230', 3),

    -- Chocker Fita Strass (2)
    ('Chocker Fita Strass',   'preto',   '#1A1A1A', 1),
    ('Chocker Fita Strass',   'marrom',  '#4A2C1A', 2),

    -- Cordão Arco Especial (1)
    ('Cordão Arco Especial',  'dourado', '#D9C46A', 5),

    -- Cordão Sol Médio (3)
    ('Cordão Sol Médio',      'preto',   '#1A1A1A', 1),
    ('Cordão Sol Médio',      'marrom',  '#4A2C1A', 2),
    ('Cordão Sol Médio',      'dourado', '#D9C46A', 5),

    -- Colar Peixe Colorido (1)
    ('Colar Peixe Colorido',  'dourado', '#D9C46A', 5),

    -- Chocker Estrela do Mar (3)
    ('Chocker Estrela do Mar','preto',   '#1A1A1A', 1),
    ('Chocker Estrela do Mar','marrom',  '#4A2C1A', 2),
    ('Chocker Estrela do Mar','oliva',   '#6E7B4F', 4),

    -- Cordão Concha Pérola (3)
    ('Cordão Concha Pérola',  'preto',   '#1A1A1A', 1),
    ('Cordão Concha Pérola',  'marrom',  '#4A2C1A', 2),
    ('Cordão Concha Pérola',  'vinho',   '#7A2230', 3)
) as v(nome, cor, cor_hex, ordem)
join bloome.acessorios a
  on lower(btrim(a.nome_acessorios)) = lower(btrim(v.nome))
on conflict (id_acessorios, cor) do nothing;

-- =====================================================================
-- ADMIN — criado manualmente, fora do seed (VALIDACAO-REGRAS §6).
--
-- O banco guarda só o hash; a senha nunca entra no SQL nem no git.
-- Gere o hash no terminal:
--
--   pip install bcrypt
--   python -c "import bcrypt,getpass; print(bcrypt.hashpw(getpass.getpass().encode(), bcrypt.gensalt()).decode())"
--
-- Depois rode o INSERT abaixo trocando o hash gerado:
--
-- insert into bloome.usuarios (usuario, senha_hash)
-- values ('admin', 'COLE_O_HASH_AQUI');
-- =====================================================================

-- =====================================================================
-- CONFERÊNCIA: 16 produtos, 49 variações, menor 18.00, maior 50.00
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

commit;
