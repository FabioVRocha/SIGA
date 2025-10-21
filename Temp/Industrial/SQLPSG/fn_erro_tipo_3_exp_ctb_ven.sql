--drop function fn_erro_tipo_3_exp_ctb_ven(bpchar, bpchar, int2, text, numeric(14, 2), int2)
--Retorna VERDADEIRO para registros com erro do tipo 3
CREATE OR REPLACE FUNCTION fn_erro_tipo_3_exp_ctb_ven(
      centro_de_custo bpchar,
      plano_de_contas bpchar,
      codigo_historico int2,
      comphist text,
      --Complemento do historico composto na funcao fn_exportacao_contabilidade_vendas
      valor numeric(14, 2),
      pri_transacao int2
   )
RETURNS boolean as $$
select 
   case
      when coalesce(
         (
            (
               case
                  when coalesce(
                     (
                        select 1
                        from ccusto
                        where ccusto = centro_de_custo
                     ),
                     0
                  ) = 1 then 1
                  else null
               end
            ) + (
               case
                  when coalesce(
                     (
                        select 1
                        from planoc
                        where planoc = plano_de_contas
                     ),
                     0
                  ) = 1 then 1
                  else null
               end
            ) + (
               case
                  when (
                     codigo_historico > 0
                     and coalesce(
                           (select 1
                           from hisctb
                           where historico = codigo_historico),
                           0
                        ) = 0
                  ) then null
                  else 1
               end
            ) + (
               case
                  when (
                     (
                        length(trim(comphist)) = 0
                        or comphist is null
                     )
                     and (
                        codigo_historico = 0
                        or codigo_historico is null
                     )
                  ) then null
                  else 1
               end
            ) + (
               case
                  when (
                     valor < 0.005
                     AND (
                        pri_transacao <> 5
                        AND pri_transacao <> 15
                     )
                  ) then null
                  else 1
               end
            )
         ),
         0
      ) = 0 then true
      else false
   end;
$$ LANGUAGE sql;   
ALTER FUNCTION fn_erro_tipo_3_exp_ctb_ven(bpchar, bpchar, int2, text, numeric(14, 2), int2) OWNER TO postgres;      