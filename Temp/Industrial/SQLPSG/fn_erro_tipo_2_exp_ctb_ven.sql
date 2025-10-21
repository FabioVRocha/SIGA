--drop function fn_erro_tipo_2_exp_ctb_ven(bpchar, int2, int2, int2)
--Retorna VERDADEIRO para registros com erro do tipo 2
CREATE OR REPLACE FUNCTION fn_erro_tipo_2_exp_ctb_ven(
      operacao bpchar,
      deposito int2,
      grupo int2,
      subgrupo int2
   ) RETURNS boolean as $$

select case
      when exists (
         select 1
         from intlanc
         where (
               (
                  intlope = operacao
                  and intldep = deposito
               )
               and (
                  (
                     intlgru = grupo
                     and intlsub = subgrupo
                  )
                  or (
                     intlgru = grupo
                     and (
                        intlsub = 0
                        or intlsub is null
                     )
                  )
                  or (
                     (
                        intlgru = 0
                        or intlgru is null
                     )
                     and (
                        intlsub = 0
                        or intlsub is null
                     )
                  )
               )
            )
      ) then false
      else true
   end;
$$ LANGUAGE sql;
ALTER FUNCTION fn_erro_tipo_2_exp_ctb_ven(bpchar, int2, int2, int2) OWNER TO postgres;      