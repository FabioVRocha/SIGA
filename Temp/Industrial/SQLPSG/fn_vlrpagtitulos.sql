-- Function: fn_vlrpagtitulos(numeric, character, character, date, smallint)

-- DROP FUNCTION fn_vlrpagtitulos(numeric, character, character, date, smallint);

CREATE OR REPLACE FUNCTION fn_vlrpagtitulos(controle numeric, titulo character, tipo character, data_ctb date, seq_ctb smallint)
  RETURNS text AS
$BODY$
DECLARE
  valor_pago numeric;
  --valor_dev numeric;
  valor_pago_liquido numeric;
  valor_acrescimo numeric;
  valor_desconto numeric;
  registro record;
BEGIN
   valor_pago      = 0.00;
   --valor_dev       = 0.00;
   valor_acrescimo = 0.00;
   valor_desconto  = 0.00;

   if trim(tipo) = 'A Receber' or  trim(tipo) = 'R' then
      for registro in (select sum(l.lacvltot) as valor_total,
                              sum(l.lacjuros) as valor_juros,
                              sum(l.lacdesco) as valor_desco
                       from public.lancai l
                       where l.laccontrol = controle
                         and l.lactitulo  = titulo
                         and l.laclanca  <= data_ctb
                         and (l.laclanca <> data_ctb or l.lacseq <= seq_ctb)
                         and l.lactransa in ('R', 'E', 'Z', 'V')) loop
         -- 'R' = Recebimento ,'E' = Entrada Bancária, 'Z' Entrada extra caixa,  'V' = devolução de venda
         valor_pago      = registro.valor_total;
         valor_acrescimo = registro.valor_juros;
         valor_desconto  = registro.valor_desco;
      end loop;

      --valor_dev  = (select sum(l.lacvltot)
      --              from lancai l
      --              where l.laccontrol = controle
      --                and l.lactitulo  = titulo
      --                and l.laclanca  <= data_ctb
      --                and (l.laclanca <> data_ctb or l.lacseq <= seq_ctb)
      --                and l.lactransa in ('F'));
      -- 'F' = Estorno
   end if;

   if trim(tipo) = 'A Pagar' or  trim(tipo) = 'P' then
      for registro in (select sum(l.lacvltot) as valor_total,
                              sum(l.lacjuros) as valor_juros,
                              sum(l.lacdesco) as valor_desco
                       from public.lancai l
                       where l.laccontrol = controle
                         and l.lactitulo  = titulo
                         and l.laclanca  <= data_ctb
                         and (l.laclanca <> data_ctb or lacseq <= seq_ctb)
                         and l.lactransa in ('P', 'Q', 'X')) loop
         -- 'P' = Pagamento,'Q' = Saída Bancária,'X' = Saída extra Caixa, 'M' = Devolução de Compra
         valor_pago      = registro.valor_total;
         valor_acrescimo = registro.valor_juros;
         valor_desconto  = registro.valor_desco;
      end loop;

      --valor_dev  = (select sum(l.lacvltot)
      --              from lancai l
      --              where l.laccontrol = controle
      --                and l.lactitulo  = titulo
      --                and l.laclanca  <= data_ctb
      --                and (l.laclanca <> data_ctb or l.lacseq <= seq_ctb)
      --                and l.lactransa in ('G'));
      -- 'G' = Estorno de saída
   end if;

   if valor_pago is null then
      valor_pago = 0.00;
   end if;

   --if valor_dev is null then
   --   valor_dev = 0.00;
   --end if;

   if valor_acrescimo is null then
      valor_acrescimo = 0.00;
   end if;

   if valor_desconto is null then
      valor_desconto = 0.00;
   end if;

   valor_pago_liquido = valor_pago;

   return valor_pago_liquido::text || ',' || valor_acrescimo::text || ',' || valor_desconto::text;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_vlrpagtitulos(numeric, character, character, date, smallint)
  OWNER TO postgres;
