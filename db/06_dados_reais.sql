-- 06_dados_reais.sql
--
-- Dados reais do catálogo (ADR-016):
--   * foto: extraída do PDF oficial `docs/referencias/Catalogo-BLOOME.pdf`
--     (páginas 2, 3, 4 e 6), recortada e otimizada em `static/imgs/*.jpg`;
--   * descrição: as 6 primeiras vêm do `catalogo.py` (texto já aprovado);
--     as 10 restantes foram escritas a partir de dados reais do PDF (nome,
--     material, categoria) e aguardam revisão da dona.
--
-- Idempotente: pode rodar de novo sem duplicar nada (só UPDATE).
-- Rodar: python db/aplicar.py --dados

begin;

update bloome.acessorios as a
set foto = d.foto, descricao = d.descricao
from (values
    (24, 'cordao_coracao.jpg',
     'Um pingente de coração em couro que une simplicidade e afeto. Feito à mão para quem gosta de detalhes que falam de dentro pra fora.'),
    (25, 'colar_inicial.jpg',
     'Colar delicado em courinho com pingente central, o primeiro passo de qualquer coleção. Um clássico discreto que combina com tudo, do dia a dia às ocasiões especiais.'),
    (26, 'cordao_amarracao.jpg',
     'Camurça soft com amarração delicada, feita para trazer leveza ao seu dia a dia. Uma peça simples e confortável, ideal para quem ama um visual minimalista e cheio de significado.'),
    (27, 'chocker_fita_pura.jpg',
     'Chocker de fita em camurça, sem pingente, para quem gosta do minimalismo puro. Sozinho ou sobreposto a outros fios, acompanha qualquer produção.'),
    (28, 'cordao_gota.jpg',
     'Pingente em formato de gota, com linhas suaves e acabamento elegante. Uma peça versátil que brilha sozinha ou em composições com outros acessórios.'),
    (29, 'colar_sao_bento.jpg',
     'Pingente de São Bento em couro, para acompanhar você na fé e na rotina. Uma peça artesanal que protege o coração e combina com qualquer produção.'),
    (30, 'chocker_olho_grego.jpg',
     'O clássico olho grego em couro, para afastar energias ruins e atrair boas vibrações. Proteção com estilo, todos os dias.'),
    (31, 'cordao_espinha_p.jpg',
     'Pingente de espinha pequena em couro, com um toque de ousadia que equilibra produções discretas. Delicada de ver, forte de presença.'),
    (32, 'cordao_arco_medio.jpg',
     'Cordão em courinho com pingente de arco médio, um desenho geométrico de linhas limpas. Peça de presença leve, ideal para o uso diário.'),
    (33, 'colar_peixe_torcido.jpg',
     'Colar em fio torcido com pingente de peixe, feito para quem gosta de detalhes com personalidade. O trançado do fio dá textura e movimento à peça.'),
    (34, 'chocker_fita_strass.jpg',
     'Chocker em fita de camurça com aplicação de strass, para dar brilho na medida. Discreto no dia a dia, especial à noite.'),
    (35, 'cordao_arco_especial.jpg',
     'Cordão em courinho dourado com pingente de arco especial, maior e mais marcante. Uma peça para quem gosta de destaque com elegância.'),
    (36, 'cordao_sol_medio.jpg',
     'Cordão em courinho com pingente de sol médio, feito para iluminar produções simples. Detalhe cheio de personalidade, sem exagero.'),
    (37, 'colar_peixe_colorido.jpg',
     'Colar em corrente com pingente de peixe colorido, um toque de cor e leveza. Perfeito para produções de verão e looks descontraídos.'),
    (38, 'chocker_estrela_do_mar.jpg',
     'Chocker em courinho com pingente de estrela do mar, inspirado na calmaria do litoral. Pequeno, delicado e cheio de significado.'),
    (39, 'cordao_concha_perola.jpg',
     'Cordão em camurça com pingente de concha e pérola, com clima de mar. Um detalhe orgânico que deixa qualquer look mais leve.')
) as d(id, foto, descricao)
where a.id_acessorios = d.id;

commit;
