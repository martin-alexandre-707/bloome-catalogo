-- =====================================================================
-- Bloome — 01_schema.sql
--
-- Papel no sistema: cria o schema `bloome`, a sequence do código público
-- e as tabelas com FKs, CHECKs, UNIQUEs e índices que transformam as
-- regras de negócio em garantias verificáveis (ADR-011/ADR-012).
--
-- Rode `00_inventario.sql` primeiro. Se algo existir em `bloome`, pare.
-- Ordem: catálogo -> contas -> pedido -> financeiro.
-- Sem DROP. O schema nasce do zero.
-- =====================================================================

begin;

create schema bloome;

-- Código público do pedido: #BLO-0001, #BLO-0002, ...
create sequence bloome.seq_pedido_codigo start 1;

-- =====================================================================
-- CATÁLOGO
-- =====================================================================

-- Matéria-prima e saldo. Estoque é de insumo, nunca de peça pronta.
create table bloome.insumos (
    id_insumos          integer generated always as identity primary key,
    nome                text not null,
    valor_unitario      numeric(10,2) not null,
    quantidade_estoque  numeric(12,3) not null default 0,
    categoria           text not null,
    unidade_medida      text not null default 'un',
    estoque_minimo      numeric(12,3) not null default 5,
    criado_em           timestamptz not null default now(),
    atualizado_em       timestamptz not null default now(),

    constraint ck_insumos_nome          check (btrim(nome) <> ''),
    constraint ck_insumos_valor         check (valor_unitario >= 0),
    constraint ck_insumos_estoque       check (quantidade_estoque >= 0),
    constraint ck_insumos_categoria     check (btrim(categoria) <> ''),
    constraint ck_insumos_unidade       check (unidade_medida in ('un','m','cm','g','kg','ml','l','par')),
    constraint ck_insumos_estoque_min   check (estoque_minimo >= 0)
);

-- EC-18: "Cordão" e "cordão" são o mesmo insumo.
create unique index ux_insumos_nome on bloome.insumos (lower(btrim(nome)));

-- Modelo do produto. Preço/material/foto são do modelo, não da cor.
-- `pingente_insumo_id` é o pingente daquele modelo (ADR-012, D2).
create table bloome.acessorios (
    id_acessorios       integer generated always as identity primary key,
    nome_acessorios     text not null,
    categoria_acessorio text not null,
    valor_acessorario   numeric(10,2) not null,
    material            text,
    foto                text,
    descricao           text,
    status              text not null default 'ativo',
    pingente_insumo_id  integer,
    criado_em           timestamptz not null default now(),
    atualizado_em       timestamptz not null default now(),

    constraint ck_acessorios_nome       check (btrim(nome_acessorios) <> ''),
    constraint ck_acessorios_categoria  check (btrim(categoria_acessorio) <> ''),
    constraint ck_acessorios_valor      check (valor_acessorario >= 0),
    constraint ck_acessorios_material   check (material is null or btrim(material) <> ''),
    constraint ck_acessorios_foto       check (foto is null or btrim(foto) <> ''),
    constraint ck_acessorios_descricao  check (descricao is null or btrim(descricao) <> ''),
    constraint ck_acessorios_status     check (status in ('ativo','volta_em_breve','removido')),
    constraint fk_acessorios_pingente   foreign key (pingente_insumo_id)
        references bloome.insumos (id_insumos) on delete restrict
);

create unique index ux_acessorios_nome on bloome.acessorios (lower(btrim(nome_acessorios)));
create index ix_acessorios_status on bloome.acessorios (status);
create index ix_acessorios_pingente on bloome.acessorios (pingente_insumo_id);

-- Uma linha por cor do modelo. A cor não muda o preço.
create table bloome.variacoes (
    id_variacao    integer generated always as identity primary key,
    id_acessorios  integer not null,
    cor            text not null,
    cor_hex        text not null,
    status         text not null default 'ativo',
    ordem          smallint not null default 0,
    criado_em      timestamptz not null default now(),
    atualizado_em  timestamptz not null default now(),

    constraint fk_variacoes_acessorios foreign key (id_acessorios)
        references bloome.acessorios (id_acessorios) on delete restrict,
    constraint ck_variacoes_cor        check (cor = lower(btrim(cor)) and btrim(cor) <> ''),
    constraint ck_variacoes_cor_hex    check (cor_hex ~ '^#[0-9A-Fa-f]{6}$'),
    constraint ck_variacoes_status     check (status in ('ativo','esgotado')),
    constraint ck_variacoes_ordem      check (ordem >= 0),
    constraint uq_variacoes_modelo_cor unique (id_acessorios, cor)
);

-- Receita de cada cor: quais insumos e quanto.
-- RESTRICT: excluir insumo ou variação não apaga receita silenciosamente.
create table bloome.composicao_variacoes (
    id_variacao  integer not null,
    id_insumos   integer not null,
    quantidade   numeric(12,3) not null,

    constraint pk_composicao_variacoes primary key (id_variacao, id_insumos),
    constraint fk_composicao_variacao  foreign key (id_variacao)
        references bloome.variacoes (id_variacao) on delete restrict,
    constraint fk_composicao_insumo    foreign key (id_insumos)
        references bloome.insumos (id_insumos) on delete restrict,
    constraint ck_composicao_quantidade check (quantidade > 0)
);

create index ix_composicao_insumo on bloome.composicao_variacoes (id_insumos);

-- =====================================================================
-- CONTAS
-- =====================================================================

-- Admin único (singleton). Não é cliente.
create table bloome.usuarios (
    id_usuarios   integer generated always as identity primary key,
    usuario       text not null,
    senha_hash    text not null,
    singleton     boolean not null default true,
    criado_em     timestamptz not null default now(),
    atualizado_em timestamptz not null default now(),

    constraint ck_usuarios_login   check (btrim(usuario) <> ''),
    constraint ck_usuarios_hash    check (length(senha_hash) >= 20),
    constraint ck_usuarios_single  check (singleton = true),
    constraint uq_usuarios_single  unique (singleton)
);

create unique index ux_usuarios_login on bloome.usuarios (lower(btrim(usuario)));

-- Comprador. E-mail normalizado e único enquanto não anonimizado (LGPD).
create table bloome.clientes (
    id_cliente      integer generated always as identity primary key,
    nome            text not null,
    email           text not null,
    senha_hash      text not null,
    telefone        text,
    anonimizado_em  timestamptz,
    criado_em       timestamptz not null default now(),
    atualizado_em   timestamptz not null default now(),

    constraint ck_clientes_nome       check (btrim(nome) <> ''),
    constraint ck_clientes_email_norm check (email = lower(btrim(email))),
    constraint ck_clientes_email_fmt  check (email ~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'),
    constraint ck_clientes_hash       check (length(senha_hash) >= 20),
    constraint ck_clientes_telefone   check (telefone is null or btrim(telefone) <> '')
);

-- EC-46/EC-51: o unique é parcial para permitir anonimização.
create unique index ux_clientes_email_ativo
    on bloome.clientes (lower(btrim(email))) where anonimizado_em is null;

-- Token de reset: só o hash entra no banco; validade de 1h; uso único.
create table bloome.recuperacao_senha (
    id_recuperacao integer generated always as identity primary key,
    id_cliente     integer not null,
    token_hash     text not null,
    criado_em      timestamptz not null default now(),
    expira_em      timestamptz not null default (now() + interval '1 hour'),
    usado_em       timestamptz,

    constraint fk_reset_cliente   foreign key (id_cliente)
        references bloome.clientes (id_cliente) on delete cascade,
    constraint uq_reset_token     unique (token_hash),
    constraint ck_reset_hash      check (length(token_hash) >= 32),
    constraint ck_reset_validade  check (expira_em > criado_em
                                     and expira_em <= criado_em + interval '1 hour')
);

create index ix_reset_cliente_valido
    on bloome.recuperacao_senha (id_cliente) where usado_em is null;
create index ix_reset_cliente on bloome.recuperacao_senha (id_cliente);

-- =====================================================================
-- PEDIDO
-- =====================================================================

-- O pedido nasce aguardando_pagamento. O total é mantido por trigger (02).
create table bloome.pedidos (
    id_pedidos          integer generated always as identity primary key,
    codigo              text not null
                        default ('#BLO-' || lpad(nextval('bloome.seq_pedido_codigo')::text, 4, '0')),
    id_cliente          integer not null,
    status              text not null default 'aguardando_pagamento',
    subtotal            numeric(10,2) not null default 0,
    frete_valor         numeric(10,2),          -- NULL = a calcular/combinar
    frete_pago_por      text not null,
    valor_total         numeric(10,2) not null default 0,
    metodo_pagamento    text not null,
    tipo_entrega        text not null,
    cep                 text,
    logradouro          text,
    numero              text,
    complemento         text,
    bairro              text,
    cidade              text,
    uf                  char(2),
    rastreio            text,
    estoque_baixado     boolean not null default false,
    idempotencia        uuid not null default gen_random_uuid(), -- evita checkout duplicado
    consumo_snapshot    jsonb,                  -- o que foi baixado (para devolver igual)
    gateway_payment_id  text,
    motivo_cancelamento text,
    reembolsado_em      timestamptz,
    reembolso_valor     numeric(10,2),
    criado_em           timestamptz not null default now(),
    atualizado_em       timestamptz not null default now(),

    constraint fk_pedidos_cliente foreign key (id_cliente)
        references bloome.clientes (id_cliente) on delete restrict,

    constraint ck_pedidos_codigo check (codigo ~ '^#BLO-[0-9]{4,}$'),
    constraint ck_pedidos_status check (status in (
        'aguardando_pagamento','pago','pago_sem_estoque','em_producao',
        'pronto_para_retirada','enviado','entregue','cancelado'
    )),
    constraint ck_pedidos_subtotal    check (subtotal >= 0),
    constraint ck_pedidos_frete       check (frete_valor is null or frete_valor >= 0),
    constraint ck_pedidos_frete_quem  check (frete_pago_por in ('cliente','loja')),
    constraint ck_pedidos_total       check (valor_total >= 0),
    constraint ck_pedidos_metodo      check (metodo_pagamento in ('pix','debito','credito')),
    constraint ck_pedidos_entrega     check (tipo_entrega in ('correios','uber_flash','retirada')),

    -- EC-29: total nunca nulo; frete indefinido entra como 0.
    constraint ck_pedidos_total_coerente
        check (valor_total = subtotal + coalesce(frete_valor, 0)),

    -- EC-30/EC-31: endereço só em Correios e completo.
    constraint ck_pedidos_endereco check (
        (tipo_entrega = 'correios'
            and cep is not null and logradouro is not null and numero is not null
            and bairro is not null and cidade is not null and uf is not null
            and frete_pago_por = 'cliente')
        or
        (tipo_entrega <> 'correios'
            and cep is null and logradouro is null and numero is null
            and complemento is null and bairro is null and cidade is null and uf is null)
    ),

    constraint ck_pedidos_frete_modalidade check (
        (tipo_entrega = 'retirada' and frete_pago_por = 'loja')
        or (tipo_entrega = 'uber_flash' and frete_pago_por = 'cliente')
        or (tipo_entrega = 'correios' and frete_pago_por = 'cliente')
    ),
    constraint ck_pedidos_retirada_frete check (
        tipo_entrega <> 'retirada' or frete_valor is null or frete_valor = 0
    ),

    -- EC-05/EC-43/EC-44: coerência entre status e baixa de estoque.
    constraint ck_pedidos_pago_sem_estoque
        check (status <> 'pago_sem_estoque' or estoque_baixado = false),
    constraint ck_pedidos_producao_estoque
        check (status not in ('pago','em_producao','pronto_para_retirada','enviado','entregue')
               or estoque_baixado = true),

    constraint ck_pedidos_cep        check (cep is null or cep ~ '^[0-9]{8}$'),
    constraint ck_pedidos_uf         check (uf is null or uf ~ '^[A-Z]{2}$'),
    constraint ck_pedidos_complemento check (complemento is null or btrim(complemento) <> ''),
    constraint ck_pedidos_logradouro check (logradouro is null or btrim(logradouro) <> ''),
    constraint ck_pedidos_numero     check (numero is null or btrim(numero) <> ''),
    constraint ck_pedidos_bairro     check (bairro is null or btrim(bairro) <> ''),
    constraint ck_pedidos_cidade     check (cidade is null or btrim(cidade) <> ''),
    constraint ck_pedidos_rastreio   check (rastreio is null or btrim(rastreio) <> ''),
    constraint ck_pedidos_motivo     check (motivo_cancelamento is null or btrim(motivo_cancelamento) <> ''),
    constraint ck_pedidos_cancelado_motivo check (
        status <> 'cancelado'
        or (motivo_cancelamento is not null and btrim(motivo_cancelamento) <> '')
    ),
    constraint ck_pedidos_reembolso  check (reembolso_valor is null or reembolso_valor >= 0),
    constraint ck_pedidos_reembolso_par check (
        (reembolsado_em is null) = (reembolso_valor is null)
    ),

    constraint uq_pedidos_codigo     unique (codigo),
    constraint uq_pedidos_idempotencia unique (idempotencia),
    constraint uq_pedidos_gateway_payment unique (gateway_payment_id)
);

create index ix_pedidos_cliente on bloome.pedidos (id_cliente, criado_em desc);
create index ix_pedidos_status on bloome.pedidos (status);
create index ix_pedidos_fila on bloome.pedidos (status, criado_em);

-- Itens gravados no checkout; preço e custo são snapshots.
create table bloome.itens_pedidos (
    id_item        integer generated always as identity primary key,
    id_pedidos     integer not null,
    id_variacao    integer not null,
    quantidade     integer not null,
    preco_unitario numeric(10,2) not null,
    custo_unitario numeric(10,2) not null,
    criado_em      timestamptz not null default now(),

    constraint fk_itens_pedido   foreign key (id_pedidos)
        references bloome.pedidos (id_pedidos) on delete restrict,
    constraint fk_itens_variacao foreign key (id_variacao)
        references bloome.variacoes (id_variacao) on delete restrict,
    constraint ck_itens_quantidade check (quantidade > 0),
    constraint ck_itens_preco      check (preco_unitario >= 0),
    constraint ck_itens_custo      check (custo_unitario >= 0),
    constraint uq_itens_pedido_variacao unique (id_pedidos, id_variacao)
);

create index ix_itens_variacao on bloome.itens_pedidos (id_variacao);

-- Log idempotente do webhook. O evento pode chegar antes do pedido.
create table bloome.eventos_pagamento (
    id_evento         integer generated always as identity primary key,
    gateway           text not null,
    evento_id         text not null,
    id_pedidos        integer,
    tipo_evento       text,
    payload           jsonb not null,
    assinatura_valida boolean not null default false,
    status_evento     text not null default 'recebido',
    tentativas        integer not null default 0,
    recebido_em       timestamptz not null default now(),
    processado_em     timestamptz,

    constraint fk_eventos_pedido foreign key (id_pedidos)
        references bloome.pedidos (id_pedidos) on delete set null,
    constraint ck_eventos_gateway  check (btrim(gateway) <> ''),
    constraint ck_eventos_gateway_norm check (gateway = lower(btrim(gateway))),
    constraint ck_eventos_id       check (btrim(evento_id) <> ''),
    constraint ck_eventos_tipo     check (tipo_evento is null or btrim(tipo_evento) <> ''),
    constraint ck_eventos_status   check (status_evento in (
        'recebido','processado','ignorado','rejeitado','aguardando_pedido','erro'
    )),
    constraint ck_eventos_assinatura check (
        status_evento <> 'processado' or assinatura_valida = true
    ),
    constraint ck_eventos_tentativas check (tentativas >= 0),
    constraint uq_eventos_gateway_id unique (gateway, evento_id)
);

create index ix_eventos_status on bloome.eventos_pagamento (status_evento);
create index ix_eventos_pedido on bloome.eventos_pagamento (id_pedidos);

-- =====================================================================
-- FINANCEIRO
-- =====================================================================

create table bloome.despesas (
    id_despesas   integer generated always as identity primary key,
    descricao     text not null,
    valor         numeric(10,2) not null,
    data_despesas timestamptz not null default now(),
    categoria     text not null,

    constraint ck_despesas_descricao check (btrim(descricao) <> ''),
    constraint ck_despesas_categoria check (btrim(categoria) <> ''),
    constraint ck_despesas_valor     check (valor > 0)
);

commit;

-- =====================================================================
-- COBERTURA DAS EDGE CASES (matriz docs/PLANO-BANCO-BLOOME.md §7.1)
--   EC-05/43/44 .......... checks de status x estoque_baixado
--   EC-13 ................ estoque_minimo DEFAULT 5
--   EC-14 ................ uq_variacoes_modelo_cor
--   EC-16/17 ............. FKs RESTRICT (receita e histórico)
--   EC-18 ................ unique funcional lower(btrim(nome))
--   EC-19 ................ checks btrim <> ''
--   EC-21/22 ............. status default + metodo_pagamento
--   EC-23/26 ............. uq_eventos_gateway_id
--   EC-25 ................ eventos_pagamento.id_pedidos nullable
--   EC-27 ................ uq_pedidos_idempotencia
--   EC-29/30/31/32 ....... checks de total, frete, endereço, CEP e UF
--   EC-34 ................ sequence + uq_pedidos_codigo + formato
--   EC-35 ................ criado_em timestamptz
--   EC-36/37 ............. uq_itens_pedido_variacao
--   EC-38 ................ snapshots preco_unitario/custo_unitario
--   EC-40 ................ ck_insumos_estoque (>= 0)
--   EC-42 ................ motivo_cancelamento/reembolsado_em/reembolso_valor
--   EC-45 ................ pedidos.id_cliente NOT NULL
--   EC-46 ................ unique parcial de e-mail
--   EC-47 ................ uq_usuarios_single
--   EC-49 ................ token único, expira_em e usado_em
--   EC-50 ................ revogação fica na função criar_recuperacao_senha
--   EC-51 ................ anonimizado_em + unique parcial
--   EC-06/EC-38 .......... consumo_snapshot + snapshots de preço/custo
--   EC-09 ................ bloqueio de DELETE via trigger (02)
--   EC-27 ................ idempotencia NOT NULL + unique
--   EC-29 ................ total por trigger BEFORE INSERT/UPDATE (02)
--
-- Funções, triggers e views vêm em 02_funcoes.sql e 03_views.sql.
-- =====================================================================
