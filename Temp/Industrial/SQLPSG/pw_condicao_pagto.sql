-- View: pw_condicao_pagto

-- DROP VIEW pw_condicao_pagto;

CREATE OR REPLACE VIEW pw_condicao_pagto AS 
 SELECT condpag.condicao AS condicaopagto_codigo_pk,
    condpag.connome AS condicaopagto_descricao
   FROM condpag
  ORDER BY condpag.connome;

ALTER TABLE pw_condicao_pagto
  OWNER TO postgres;

