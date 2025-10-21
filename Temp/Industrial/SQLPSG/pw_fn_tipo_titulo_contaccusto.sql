-- Function: pw_fn_tipo_titulo_contaccusto(numeric, text, numeric)
-- DROP FUNCTION pw_fn_tipo_titulo_contaccusto(numeric, text, numeric);
CREATE OR REPLACE FUNCTION pw_fn_tipo_titulo_contaccusto(pcontrole numeric, ptitulo text, pdeposito numeric) RETURNS text AS $BODY$
declare
multiempresa char;
recpag char;
valor text;
begin multiempresa := (
  select dadmulemp
  from dadosemp
  limit 1
);
recpag := (
  select titrecpag
  from titulos t
  where t.controle = pcontrole
    and t.titulo = ptitulo
); 

select array_to_json(array[row_to_json(sub)])
from
(select case
            when recpag in ('R', 'N') then trim(PRT1CCDEB)
            when recpag in ('P', 'M') then trim(PRT1CCCRE)
        end as ccusto,
        case
            when recpag in ('R', 'N') then trim(PRT1PCDEB)
            when recpag in ('P', 'M') then trim(PRT1PCCRE)
        end as planoc
        from prtipo1
        where prtipo in (
                select tittipo
                from titulos t
                where t.controle = pcontrole
                and t.titulo = ptitulo
                )  and (((prtdeposit = pdeposito or prtdeposit = 0) and multiempresa = 'S') or (prtdeposit = 0 and multiempresa <> 'S'))
                and ((trim(coalesce(PRT1CCDEB, '')) <> '' and trim(coalesce(PRT1PCDEB, '')) <> '' and recpag in ('R', 'N'))
                or (trim(coalesce(PRT1CCCRE, '')) <> '' and trim(coalesce(PRT1PCCRE, '')) <> '' and recpag in ('P', 'M')))
        order by 
          case     			    
            when prtdeposit = pdeposito and multiempresa = 'S' then 1
            else 2
          end
        limit 1) as sub into valor;

return coalesce(valor, '');

END;
$BODY$ LANGUAGE plpgsql VOLATILE COST 100;
ALTER FUNCTION pw_fn_tipo_titulo_contaccusto(numeric, text, numeric)
SET search_path = public,
  pg_temp;
ALTER FUNCTION pw_fn_tipo_titulo_contaccusto(numeric, text, numeric) OWNER TO postgres;