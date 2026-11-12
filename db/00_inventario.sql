-- =====================================================================
-- Bloome — 00_inventario.sql
-- SOMENTE LEITURA. Não cria, não altera, não apaga nada.
--
-- Objetivo: confirmar o estado do Supabase antes de qualquer DDL.
-- Rode no SQL Editor do Supabase e guarde o resultado.
-- Se o item 1 ou 2 retornar linhas, PARE: já existe algo em `bloome`.
-- =====================================================================

-- 1. O schema alvo já existe?
select
    n.nspname                          as schema,
    pg_get_userbyid(n.nspowner)        as dono
from pg_namespace n
where n.nspname = 'bloome';

-- 2. Objetos já existentes dentro de `bloome` (tabelas, views, sequences)
select
    c.relkind                          as tipo,  -- r=tabela, v=view, S=sequence...
    c.relname                          as nome
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'bloome'
order by c.relkind, c.relname;

-- 3. Funções já existentes dentro de `bloome`
select
    p.proname                          as funcao,
    pg_get_function_identity_arguments(p.oid) as argumentos
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'bloome'
order by p.proname;

-- 4. Tabelas em `public` (o legado/algum resto pode estar aqui)
select
    t.table_schema,
    t.table_name
from information_schema.tables t
where t.table_schema = 'public'
  and t.table_type = 'BASE TABLE'
order by t.table_name;

-- 5. Sequences em `public` (evita colisão de nomes)
select
    s.sequence_schema,
    s.sequence_name
from information_schema.sequences s
where s.sequence_schema in ('bloome', 'public')
order by s.sequence_schema, s.sequence_name;

-- 6. Extensões instaladas (nenhuma é obrigatória para o MVP)
select
    e.extname,
    e.extversion
from pg_extension e
order by e.extname;

-- 7. Contexto da sessão e permissão para criar schema
select
    current_user                       as usuario_atual,
    current_database()                 as banco,
    version()                          as versao,
    now()                              as agora,
    has_database_privilege(current_user, current_database(), 'CREATE')
                                       as pode_criar_schema;

-- =====================================================================
-- Resultado esperado
--   1 e 2: nenhuma linha  -> schema `bloome` limpo, pode seguir.
--   4: linhas são aceitáveis em `public` (ex.: objetos do Supabase),
--      mas NÃO devem conter as tabelas legadas do gestão.
--   6: normalmente inclui plpgsql; nada mais é exigido.
--   7: pode_criar_schema = true.
-- Se algo inesperado aparecer: PARE e decida. Nunca use DROP.
-- =====================================================================
