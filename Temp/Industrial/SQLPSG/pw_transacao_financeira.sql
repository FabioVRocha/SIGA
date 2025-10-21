-- View: pw_transacao_financeira

-- DROP VIEW pw_transacao_financeira;

CREATE OR REPLACE VIEW pw_transacao_financeira AS 
 SELECT unnest(ARRAY['A'::text, 'B'::text, 'C'::text, 'D'::text, 'E'::text, 'F'::text, 'G'::text, 'H'::text, 'I'::text, 'J'::text, 'k'::text, 'M'::text, 'N'::text, 'P'::text, 'Q'::text, 'R'::text, 'S'::text, 'T'::text, 'U'::text, 'V'::text, '#'::text, 'X'::text, 'Y'::text, 'Z'::text, '0'::text, '1'::text, '2'::text, '3'::text, '4'::text, '5'::text, '6'::text, '7'::text, '8'::text, '9'::text]) AS transacaofinanceira_codigo_pk,
    unnest(ARRAY['Débitos Bancários Múltiplos'::text, 'Adiantamento Banco'::text, 'Adiantamento Caixa'::text, 'Depósito Bancário'::text, 'Entrada Bancária'::text, 'Depósito de Cheques'::text, 'Recebimentos Múltiplos'::text, 'Créditos Bancários Múltiplos'::text, 'Saque Múltiplo'::text, 'Desconto de Cheques'::text, 'Compensação de Cartões'::text, 'Pagamentos Múltiplos'::text, 'Duplicatas Descontadas'::text, 'Saída ( Pagto ) Caixa'::text, 'Saída Bancária'::text, 'Entrada ( Recto ) Caixa'::text, 'Saque Bancário'::text, 'Saída entre Bancos'::text, 'Entrada entre Bancos'::text, 'Devoluções de Vendas'::text, 'Devoluções de Compras'::text, 'Pagamentos Extra Caixa'::text, 'Troca de Cheque por Dinheiro'::text, 'Recebimentos Extra Caixa'::text, 'Pag. Extra Caixa -> Contab'::text, 'Adiantamento Clientes'::text, 'Adiantamento Clientes /Banco'::text, 'Adiantamento Fornecedores'::text, 'Adiantamento Fornec. /Banco'::text, 'Devolução Adiant. Clientes'::text, 'Devol. Adiant. Clientes /Banco'::text, 'Devol. Adiantamento Fornecedores'::text, 'Devol. Adiant.Fornec. /Banco'::text, 'Receb. Extra Caixa -> Contab'::text]) AS transacaofinanceira_descricao;

ALTER TABLE pw_transacao_financeira
  OWNER TO postgres;

