-- Favoritos: um cliente marca um produto do catálogo.
-- Chave composta garante que a mesma pessoa não favorite duas vezes.
-- Idempotente: pode rodar de novo sem erro.

create table if not exists bloome.favoritos (
    id_cliente     integer     not null references bloome.clientes(id_cliente),
    id_acessorios  integer     not null references bloome.acessorios(id_acessorios),
    criado_em      timestamptz not null default now(),
    primary key (id_cliente, id_acessorios)
);

-- Índice na FK "do outro lado": consultas por produto (ex.: contagem)
-- e a checagem de integridade do banco não varrem a tabela inteira.
create index if not exists ix_favoritos_acessorio
    on bloome.favoritos (id_acessorios);
