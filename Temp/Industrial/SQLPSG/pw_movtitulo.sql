-- View: pw_movtitulo
-- DROP VIEW pw_movtitulo;
create
or replace
view pw_movtitulo as
select
	titulos_pagamentos.controle as movtitulo_titulo_controle_fk,
	titulos_pagamentos.titulo as movtitulo_titulo_codigo_fk,
	greatest(
        titulos_pagamentos.data_caixa,
        '0001-01-01' :: date
    ) as movtitulo_data_caixa,
	greatest(titulos_pagamentos.seq :: integer, 0) as movtitulo_caixa_sequencia,
	case
		when titulos_pagamentos.dtpagamento is null
		or titulos_pagamentos.dtpagamento = '0001-01-01' :: date then case
			when (
                'now' :: text :: date - titulos_pagamentos.vencimento
            ) < 0 then 0
			else 'now' :: text :: date - titulos_pagamentos.vencimento
		end
		else case
			when (
                titulos_pagamentos.dtpagamento - titulos_pagamentos.vencimento
            ) < 0 then 0
			else titulos_pagamentos.dtpagamento - titulos_pagamentos.vencimento
		end
	end as movtitulo_qtde_dias_atraso,
	greatest(titulos_pagamentos.valor_total, 0.00) as movtitulo_valor_total_caixa,
	greatest(titulos_pagamentos.valor_caixa, 0.00) as movtitulo_valor_caixa,
	greatest(titulos_pagamentos.valor_acrescimo, 0.00) as movtitulo_valor_acrescimo_caixa,
	greatest(titulos_pagamentos.valor_desconto, 0.00) as movtitulo_valor_desconto_caixa,
	titulos_pagamentos.valor_pgtos [1] :: numeric(14,
	2) as movtitulo_valor_pgto_acumulado_caixa,
	titulos_pagamentos.valor_pgtos [2] :: numeric(14,
	2) as movtitulo_valor_acrescimo_acumulado_caixa,
	titulos_pagamentos.valor_pgtos [3] :: numeric(14,
	2) as movtitulo_valor_desconto_acumulado_caixa,
	titulos_pagamentos.valor_total - titulos_pagamentos.valor_pgtos [1] :: numeric(14,
	2) as movtitulo_valor_saldo_caixa,
	titulos_pagamentos.ccusto_credito as movtitulo_ccusto_credito_fk,
	titulos_pagamentos.conta_credito as movtitulo_conta_credito_fk,
	titulos_pagamentos.conta_contabil_c as movtitulo_conta_contabil_c,
	titulos_pagamentos.ccusto_debito as movtitulo_ccusto_debito_fk,
	titulos_pagamentos.conta_debito as movtitulo_conta_debito_fk,
	titulos_pagamentos.conta_contabil_d as movtitulo_conta_contabil_d,
	titulos_pagamentos.data_envio_banco as movtitulo_data_envio_banco,
	titulos_pagamentos.data_retorno_banco as movtitulo_data_retorno_banco,
	titulos_pagamentos.data_protestar as movtitulo_data_protestar,
	titulos_pagamentos.data_protesto as movtitulo_data_protesto,
	titulos_pagamentos.tipo_movimentacao as movtitulo_tipo_movimentacao_fk
from
	(
	select
		t.controle,
		t.titulo,
		t.titdtpag as dtpagamento,
		t.titoperaca as cfop,
		case
			when t.titrecpag = 'R' :: bpchar then 'A Receber' :: character(10)
			when t.titrecpag = 'P' :: bpchar then 'A Pagar' :: character(10)
			else t.titrecpag :: character(10)
		end as rec_pag,
		t.titvltotal as valor_total,
		t.titemissao as emissao,
		t.titvencto as vencimento,
		lan.lacvltot as valor_caixa,
		lan.lacjuros as valor_acrescimo,
		lan.lacdesco as valor_desconto,
		lan.laclanca as data_caixa,
		lan.lacseq as seq,
		lan.ccusto_credito,
		lan.conta_credito,
		lan.conta_contab_c as conta_contabil_c,
		lan.ccusto_debito,
		lan.conta_debito,
		lan.conta_contab_d as conta_contabil_d,
		t.titdepori as deposito,
		string_to_array(
                fn_vlrpagtitulos(
                    t.controle :: numeric,
                    t.titulo,
                    t.titrecpag,
                    lan.laclanca,
                    lan.lacseq
                ),
                ',' :: text
            ) as valor_pgtos,
		"int".intbenvio as data_envio_banco,
		"int".intbdtret as data_retorno_banco,
		"int".intdtapr as data_protestar,
		pro.protdata as data_protesto,
		case
			when lan.lactransa = any (
                    array ['V'::bpchar,
			'#'::bpchar,
			'X'::bpchar,
			'0'::bpchar,
			'Z'::bpchar,
			'9'::bpchar]
                ) then 'S' :: character(1)
			else 'N' :: character(1)
		end as tipo_movimentacao
	from
		titulos t
	left join (
		select
			i.intcontrol,
			i.inttitulo,
			i.intbenvio,
			i.intbdtret,
			i.intdtapr
		from
			titbanco i
            ) "int" on
		"int".intcontrol = t.controle
		and "int".inttitulo = t.titulo
	left join (
		select
			p.protcontro,
			p.prottitulo,
			p.protdata
		from
			protesto p
            ) pro on
		pro.protcontro = t.controle
		and pro.prottitulo = t.titulo
	left join (
		select
			l.laclanca,
			l.lacseq,
			l.lactransa,
			l.laccontrol,
			l.lactitulo,
			l.lacvltot,
			l.lacjuros,
			l.lacdesco,
			case
				when l.lactransa = 'A' :: bpchar then deb.lacccusto :: text
				when l.lactransa = 'Q' :: bpchar then aux.laaccusto :: text
				when l.lactransa = 'T' :: bpchar then l.lacccusto :: text
				when l.lactransa = 'E' :: bpchar then aux.laaccusto :: text
				when l.lactransa = 'H' :: bpchar then l.lacccusto :: text
				when l.lactransa = '1' :: bpchar then l.lacccusto :: text
				when l.lactransa = '2' :: bpchar then l.lacccusto :: text
				when l.lactransa = '4' :: bpchar then aux.laaccusto :: text
				when l.lactransa = '9' :: bpchar then l.lacccusto :: text
				when l.lactransa = '0' :: bpchar then aux.laaccusto :: text
				when l.lactransa = 'G' :: bpchar then l.lacccusto :: text
				when l.lactransa = 'F' :: bpchar then dep.pcxcccheq :: text
				when l.lactransa = 'N' :: bpchar then l.lacccusto :: text
				when l.lactransa = 'R' :: bpchar then l.lacccusto :: text
				when l.lactransa = 'P' :: bpchar then dep.pcxcccaixa :: text
				when l.lactransa = '8' :: bpchar then l.lacccusto :: text
				when l.lactransa = '3' :: bpchar then dep.pcxcccaixa :: text
				when l.lactransa = 'J' :: bpchar then dep.pcxcccheq :: text
				when l.lactransa = 'Y' :: bpchar then dep.pcxcccheq :: text
				when l.lactransa = '6' :: bpchar then aux.laaccusto :: text
				when l.lactransa = 'M' :: bpchar then case
					when lac.lactransa = 'P' :: bpchar then case
						when lcmul.constalacmul > 0 then case
							when chq.constachquso1 > 0 then case
								when length(btrim(prt1.prt1pcdeb :: text)) > 0 then prt1.prt1ccdeb :: text
								else case
									when length(btrim(prt12.prt1pcdeb :: text)) > 0 then prt12.prt1ccdeb :: text
									else '' :: text
								end
							end
							else case
								when chq2.constachquso2 > 0
									and cprm.naopreenchidopcxpccheq = 0 then dep.pcxcccaixa :: text
									else dep.pcxcccheq :: text
								end
							end
							else null :: text
						end
						else lac.lacccusto :: text
					end
					else '' :: text
				end as ccusto_credito,
				case
					when l.lactransa = 'A' :: bpchar then deb.lacplanoc :: text
					when l.lactransa = 'Q' :: bpchar then aux.laaplanoc :: text
					when l.lactransa = 'T' :: bpchar then l.lacplanoc :: text
					when l.lactransa = 'E' :: bpchar then l.lacplanoc :: text
					when l.lactransa = 'H' :: bpchar then l.lacplanoc :: text
					when l.lactransa = '1' :: bpchar then l.lacplanoc :: text
					when l.lactransa = '2' :: bpchar then l.lacplanoc :: text
					when l.lactransa = '4' :: bpchar then aux.laaplanoc :: text
					when l.lactransa = '9' :: bpchar then l.lacplanoc :: text
					when l.lactransa = '0' :: bpchar then aux.laaplanoc :: text
					when l.lactransa = 'G' :: bpchar then l.lacplanoc :: text
					when l.lactransa = 'F' :: bpchar then dep.pcxpccheq :: text
					when l.lactransa = 'N' :: bpchar then l.lacplanoc :: text
					when l.lactransa = 'R' :: bpchar then l.lacplanoc :: text
					when l.lactransa = 'P' :: bpchar then dep.pcxpccaixa :: text
					when l.lactransa = '8' :: bpchar then l.lacplanoc :: text
					when l.lactransa = '3' :: bpchar then dep.pcxpccaixa :: text
					when l.lactransa = 'J' :: bpchar then dep.pcxpccheq :: text
					when l.lactransa = 'Y' :: bpchar then dep.pcxpccheq :: text
					when l.lactransa = '6' :: bpchar then aux.laaplanoc :: text
					when l.lactransa = 'M' :: bpchar then case
						when lac.lactransa = 'P' :: bpchar then case
							when lcmul.constalacmul > 0 then case
								when chq.constachquso1 > 0 then case
									when length(btrim(prt1.prt1pcdeb :: text)) > 0 then prt1.prt1pcdeb :: text
									else case
										when length(btrim(prt12.prt1pcdeb :: text)) > 0 then prt12.prt1pcdeb :: text
										else '' :: text
									end
								end
								else case
									when chq2.constachquso2 > 0
										and cprm.naopreenchidopcxpccheq = 0 then dep.pcxpccaixa :: text
										else dep.pcxpccheq :: text
									end
								end
								else null :: text
							end
							else case
								when dep.pcxchpro = 'C' :: bpchar then dep.pcxpcchpro :: text
								else lac.lacplanoc :: text
							end
						end
						else '' :: text
					end as conta_credito,
					case
						when l.lactransa = 'A' :: bpchar then ple.plcnome :: text
						when l.lactransa = 'Q' :: bpchar then plx.plcnome :: text
						when l.lactransa = 'T' :: bpchar then plc.plcnome :: text
						when l.lactransa = 'E' :: bpchar then plc.plcnome :: text
						when l.lactransa = 'H' :: bpchar then plc.plcnome :: text
						when l.lactransa = '1' :: bpchar then plc.plcnome :: text
						when l.lactransa = '2' :: bpchar then plc.plcnome :: text
						when l.lactransa = '4' :: bpchar then plx.plcnome :: text
						when l.lactransa = '9' :: bpchar then plc.plcnome :: text
						when l.lactransa = '0' :: bpchar then plx.plcnome :: text
						when l.lactransa = 'G' :: bpchar then plc.plcnome :: text
						when l.lactransa = 'F' :: bpchar then plr.plcnome :: text
						when l.lactransa = 'N' :: bpchar then plc.plcnome :: text
						when l.lactransa = 'R' :: bpchar then plc.plcnome :: text
						when l.lactransa = 'P' :: bpchar then plr.plcnome :: text
						when l.lactransa = '8' :: bpchar then plc.plcnome :: text
						when l.lactransa = '3' :: bpchar then plr.plcnome :: text
						when l.lactransa = 'J' :: bpchar then plr.plcnome :: text
						when l.lactransa = 'Y' :: bpchar then plr.plcnome :: text
						when l.lactransa = '6' :: bpchar then plx.plcnome :: text
						when l.lactransa = 'M' :: bpchar then case
							when lac.lactransa = 'P' :: bpchar then case
								when lcmul.constalacmul > 0 then case
									when chq.constachquso1 > 0 then case
										when length(btrim(prt1.prt1pcdeb :: text)) > 0 then plcmul2.plcnome :: text
										else case
											when length(btrim(prt12.prt1pcdeb :: text)) > 0 then plcmul3.plcnome :: text
											else '' :: text
										end
									end
									else case
										when chq2.constachquso2 > 0
											and cprm.naopreenchidopcxpccheq = 0 then plr.plcnome :: text
											else plr.plcnome :: text
										end
									end
									else null :: text
								end
								else case
									when dep.pcxchpro = 'C' :: bpchar then plccheq.plcnome :: text
									else plcmul1.plcnome :: text
								end
							end
							else '' :: text
						end as conta_contab_c,
						case
							when l.lactransa = 'A' :: bpchar then l.lacccusto :: text
							when l.lactransa = 'Q' :: bpchar then l.lacccusto :: text
							when l.lactransa = 'U' :: bpchar then l.lacccusto :: text
							when l.lactransa = 'E' :: bpchar then aux.laaccusto :: text
							when l.lactransa = 'H' :: bpchar then rec.lacccusto :: text
							when l.lactransa = '1' :: bpchar then dep.pcxcccaixa :: text
							when l.lactransa = '2' :: bpchar then aux.laaccusto :: text
							when l.lactransa = '4' :: bpchar then l.lacccusto :: text
							when l.lactransa = '9' :: bpchar then aux.laaccusto :: text
							when l.lactransa = '0' :: bpchar then l.lacccusto :: text
							when l.lactransa = 'G' :: bpchar then dep.pcxcccheq :: text
							when l.lactransa = 'F' :: bpchar then l.lacccusto :: text
							when l.lactransa = 'R' :: bpchar then dep.pcxcccheq :: text
							when l.lactransa = 'P' :: bpchar then l.lacccusto :: text
							when l.lactransa = '8' :: bpchar then aux.laaccusto :: text
							when l.lactransa = '3' :: bpchar then l.lacccusto :: text
							when l.lactransa = 'J' :: bpchar then aux.laaccusto :: text
							when l.lactransa = 'Y' :: bpchar then dep.pcxcccaixa :: text
							when l.lactransa = '6' :: bpchar then l.lacccusto :: text
							when l.lactransa = 'M' :: bpchar then l.lacccusto :: text
							else '' :: text
						end as ccusto_debito,
						case
							when l.lactransa = 'A' :: bpchar then l.lacplanoc :: text
							when l.lactransa = 'Q' :: bpchar then l.lacplanoc :: text
							when l.lactransa = 'U' :: bpchar then l.lacplanoc :: text
							when l.lactransa = 'E' :: bpchar then aux.laaplanoc :: text
							when l.lactransa = 'H' :: bpchar then rec.lacplanoc :: text
							when l.lactransa = '1' :: bpchar then dep.pcxpccaixa :: text
							when l.lactransa = '2' :: bpchar then aux.laaplanoc :: text
							when l.lactransa = '4' :: bpchar then l.lacplanoc :: text
							when l.lactransa = '9' :: bpchar then aux.laaplanoc :: text
							when l.lactransa = '0' :: bpchar then l.lacplanoc :: text
							when l.lactransa = 'G' :: bpchar then dep.pcxpccheq :: text
							when l.lactransa = 'F' :: bpchar then l.lacplanoc :: text
							when l.lactransa = 'R' :: bpchar then dep.pcxpccheq :: text
							when l.lactransa = 'P' :: bpchar then l.lacplanoc :: text
							when l.lactransa = '8' :: bpchar then aux.laaplanoc :: text
							when l.lactransa = '3' :: bpchar then l.lacplanoc :: text
							when l.lactransa = 'J' :: bpchar then aux.laaplanoc :: text
							when l.lactransa = 'Y' :: bpchar then dep.pcxpccaixa :: text
							when l.lactransa = '6' :: bpchar then l.lacplanoc :: text
							when l.lactransa = 'M' :: bpchar then l.lacplanoc :: text
							else '' :: text
						end as conta_debito,
						case
							when l.lactransa = 'A' :: bpchar then plc.plcnome :: text
							when l.lactransa = 'Q' :: bpchar then plc.plcnome :: text
							when l.lactransa = 'U' :: bpchar then plc.plcnome :: text
							when l.lactransa = 'E' :: bpchar then plx.plcnome :: text
							when l.lactransa = 'H' :: bpchar then prr.plcnome :: text
							when l.lactransa = '1' :: bpchar then plr.plcnome :: text
							when l.lactransa = '2' :: bpchar then plx.plcnome :: text
							when l.lactransa = '4' :: bpchar then plc.plcnome :: text
							when l.lactransa = '9' :: bpchar then plx.plcnome :: text
							when l.lactransa = '0' :: bpchar then plc.plcnome :: text
							when l.lactransa = 'G' :: bpchar then plr.plcnome :: text
							when l.lactransa = 'F' :: bpchar then plc.plcnome :: text
							when l.lactransa = 'R' :: bpchar then plr.plcnome :: text
							when l.lactransa = 'P' :: bpchar then plc.plcnome :: text
							when l.lactransa = '8' :: bpchar then plx.plcnome :: text
							when l.lactransa = '3' :: bpchar then plc.plcnome :: text
							when l.lactransa = 'J' :: bpchar then plx.plcnome :: text
							when l.lactransa = 'Y' :: bpchar then plr.plcnome :: text
							when l.lactransa = '6' :: bpchar then plc.plcnome :: text
							when l.lactransa = 'M' :: bpchar then plc.plcnome :: text
							else '' :: text
						end as conta_contab_d
					from
						lancai l
					left join (
						select
							n.planoc,
							n.plcnome
						from
							planoc n
                    ) plc on
						plc.planoc = l.lacplanoc
					left join (
						select
							d.deposito,
							d.depdepman,
							par.pcxparam,
							par.pcxpccaixa,
							par.pcxpccli,
							par.pcxpcfor,
							par.pcxpcjurco,
							par.pcxpcdesco,
							par.pcxpcjurpa,
							par.pcxpcdesre,
							par.pcxpcadsal,
							par.pcxpcdupde,
							par.pcxpcdespb,
							par.pcxpcant,
							par.pcxpcfan,
							par.pcxpcvvi,
							par.pcxpccvi,
							par.pcxpccomi,
							par.pcxpcdvven,
							par.pcxpcdvcom,
							par.pcxpctrati,
							par.pcxpciof,
							par.pcxpccheq,
							par.pcxpcchpro,
							par.pcxpctarif,
							par.pcxpccarta,
							par.pcxcccaixa,
							par.pcxcccli,
							par.pcxccfor,
							par.pcxccjurco,
							par.pcxccdesco,
							par.pcxccjurpa,
							par.pcxccdesre,
							par.pcxccadsal,
							par.pcxccdupde,
							par.pcxccdespb,
							par.pcxccant,
							par.pcxccfan,
							par.pcxccvvi,
							par.pcxcccvi,
							par.pcxcccomi,
							par.pcxccdvven,
							par.pcxccdvcom,
							par.pcxcctrati,
							par.pcxcciof,
							par.pcxcccheq,
							par.pcxctarifa,
							par.pcxcccarta,
							par.pcxchpro
						from
							deposito d
						left join (
							select
								p.pcxparam,
								p.pcxpccaixa,
								p.pcxpccli,
								p.pcxpcfor,
								p.pcxpcjurco,
								p.pcxpcdesco,
								p.pcxpcjurpa,
								p.pcxpcdesre,
								p.pcxpcadsal,
								p.pcxpcdupde,
								p.pcxpcdespb,
								p.pcxpcant,
								p.pcxpcfan,
								p.pcxpcvvi,
								p.pcxpccvi,
								p.pcxpccomi,
								p.pcxpcdvven,
								p.pcxpcdvcom,
								p.pcxpctrati,
								p.pcxpciof,
								p.pcxpccheq,
								p.pcxpcchpro,
								p.pcxpctarif,
								p.pcxpccarta,
								p.pcxcccaixa,
								p.pcxcccli,
								p.pcxccfor,
								p.pcxccjurco,
								p.pcxccdesco,
								p.pcxccjurpa,
								p.pcxccdesre,
								p.pcxccadsal,
								p.pcxccdupde,
								p.pcxccdespb,
								p.pcxccant,
								p.pcxccfan,
								p.pcxccvvi,
								p.pcxcccvi,
								p.pcxcccomi,
								p.pcxccdvven,
								p.pcxccdvcom,
								p.pcxcctrati,
								p.pcxcciof,
								p.pcxcccheq,
								p.pcxctarifa,
								p.pcxcccarta,
								p.pcxchpro
							from
								caiparam p
                            ) par on
							par.pcxparam = d.depdepman
                    ) dep on
						dep.deposito = l.lacdeposit
					left join (
						select
							n.planoc,
							n.plcnome
						from
							planoc n
                    ) plr on
						plr.planoc = dep.pcxpccaixa
					left join (
						select
							x.lacauxlanc,
							x.lacauxseq,
							x.laahistori,
							x.laadescri,
							x.laaccusto,
							x.laaplanoc,
							x.laared
						from
							lacaaux x
                    ) aux on
						aux.lacauxlanc = l.laclanca
						and aux.lacauxseq = l.lacseq
					left join (
						select
							n.planoc,
							n.plcnome
						from
							planoc n
                    ) plx on
						plx.planoc = aux.laaplanoc
					left join (
						select
							d.dbmdata,
							d.dbmconta,
							d.dbmseq,
							d.dbmoriseq,
							lad.lacbanco,
							lad.lacccusto,
							lad.lacplanoc
						from
							debmul d
						left join (
							select
								a.laclanca,
								a.lacseq,
								a.lacbanco,
								a.lacccusto,
								a.lacplanoc
							from
								lancai a
                            ) lad on
							lad.laclanca = d.dbmdata
							and lad.lacseq = d.dbmoriseq
                    ) deb on
						deb.dbmdata = l.laclanca
						and deb.dbmseq = l.lacseq
					left join (
						select
							n.planoc,
							n.plcnome
						from
							planoc n
                    ) ple on
						ple.planoc = deb.lacplanoc
					left join (
						select
							sub1.datalcto as rcmdata,
							sub1.contalcto as rcmconta,
							sub1.seqlcto as rcmseq,
							sub1.seqorilcto as rcmoriseq,
							sub1.bcolcto as lacbanco,
							sub1.custolcto as lacccusto,
							sub1.planoclcto as lacplanoc
						from
							(
							select
								r.rcmdata as datalcto,
								r.rcmconta as contalcto,
								r.rcmseq as seqlcto,
								r.rcmoriseq as seqorilcto,
								lar.lacbanco as bcolcto,
								lar.lacccusto as custolcto,
								lar.lacplanoc as planoclcto
							from
								recmul r
							left join (
								select
									a.laclanca,
									a.lacseq,
									a.lacbanco,
									a.lacccusto,
									a.lacplanoc
								from
									lancai a
                                    ) lar on
								lar.laclanca = r.rcmdata
								and lar.lacseq = r.rcmoriseq
                            ) sub1,
							(
							select
								rec.rcmdata as datasub2,
								rec.rcmseq as seqsub2,
								case
									when (rec.contarec :: numeric - sum(somachp.soma)) > 0 :: numeric then 'S' :: text
									else 'N' :: text
								end as temrecebimentoemdinheiro
							from
								(
								select
									recmul.rcmdata,
									recmul.rcmconta,
									recmul.rcmseq,
									recmul.rcmoriseq,
									recmul.rcmtipo,
									recmul.rcmcli,
									chp.soma
								from
									recmul,
									(
									select
										count(*) as soma,
										chpredat.chdtlanca,
										chpredat.chselanca
									from
										chpredat
									group by
										chpredat.chdtlanca,
										chpredat.chselanca
                                            ) chp
								where
									chp.chdtlanca = recmul.rcmdata
									and chp.chselanca = recmul.rcmoriseq
                                    ) somachp,
								(
								select
									count(*) as contarec,
									recmul.rcmdata,
									recmul.rcmseq
								from
									recmul
								group by
									recmul.rcmdata,
									recmul.rcmseq
                                    ) rec
							where
								somachp.rcmdata = rec.rcmdata
								and somachp.rcmseq = rec.rcmseq
							group by
								somachp.rcmdata,
								rec.contarec,
								rec.rcmdata,
								rec.rcmseq
							order by
								somachp.rcmdata
                            ) sub2
						where
							sub2.datasub2 = sub1.datalcto
							and sub2.seqsub2 = sub1.seqlcto
							and (
                                (
                                    sub1.datalcto :: text || sub1.seqorilcto in (
							select
								chpredat.chdtlanca :: text || chpredat.chselanca :: text
							from
								chpredat
                                    )
                                )
							and sub2.temrecebimentoemdinheiro = 'N' :: text
							or not (
                                    sub1.datalcto :: text || sub1.seqorilcto in (
							select
								chpredat.chdtlanca :: text || chpredat.chselanca :: text
							from
								chpredat
                                    )
                                )
							and sub2.temrecebimentoemdinheiro = 'S' :: text
                            )
                    ) rec on
						rec.rcmdata = l.laclanca
						and rec.rcmseq = l.lacseq
					left join (
						select
							n.planoc,
							n.plcnome
						from
							planoc n
                    ) prr on
						prr.planoc = rec.lacplanoc
					left join (
                        with chp as(
						select
							CHDTLANCA,
							CHSELANCA,
							CHDTLACDES,
							CHSELACDES,
							CH2DTLACDE,
							CH2SEQLAC
						from
							chpredat
						where
							ch2dtlacde is not null
							and ch2seqlac is not null
                        ),
						chp2 as (
						select
							CHDTLANCA,
							CHSELANCA,
							CHDTLACDES,
							CHSELACDES,
							CH2DTLACDE,
							CH2SEQLAC
						from
							chpredat
						where
							chdtlacdes is not null
							and chselacdes is not null
                        ),
						chp3 as (
						select
							CHDTLANCA,
							CHSELANCA,
							CHDTLACDES,
							CHSELACDES,
							CH2DTLACDE,
							CH2SEQLAC
						from
							chpredat
						where
							chdtlanca is not null
							and chselanca is not null
                        )
						select
							distinct on
							(lcmul.lcmdata,
							lcmul.lcmseq) lcmul.lcmdata,
							lcmul.lcmseq,
							lcmul.lcmoriseq,
							lcai.lacccusto,
							lcai.lacplanoc,
							lcai.lactransa,
							lcai.laclanca,
							lcai.lacseq,
							lcai.lacdeposit
						from
							lacmul lcmul
						left join chp3 on
							(
                                chp3.chdtlanca = lcmul.lcmdata
								and chp3.chselanca = lcmul.lcmoriseq
                            )
						left join chp2 on
							(
                                chp2.chdtlacdes = lcmul.lcmdata
								and chp2.chselacdes = lcmul.lcmoriseq
                            )
						left join chp on
							(
                                chp.ch2dtlacde = lcmul.lcmdata
								and chp.ch2seqlac = lcmul.lcmoriseq
                            )
						left join lancai lcai on
							lcai.laclanca = lcmul.lcmdata
							and lcai.lacseq = lcmul.lcmoriseq
						order by
							lcmul.lcmdata,
							lcmul.lcmseq,
							case
								when lcmul.lcmdata = chp3.chdtlanca
								and lcmul.lcmoriseq = chp3.chselanca then 2
								when lcmul.lcmdata = chp2.chdtlacdes
								and lcmul.lcmoriseq = chp2.chselacdes then 3
								when lcmul.lcmdata = chp.ch2dtlacde
								and lcmul.lcmoriseq = chp.ch2seqlac then 3
								else 1
							end
                    ) lac on
						lac.lcmdata = l.laclanca
						and lac.lcmseq = l.lacseq
					left join (
						select
							planoc.planoc,
							planoc.plcnome
						from
							planoc
                    ) plccheq on
						plccheq.planoc = dep.pcxpcchpro
					left join (
						select
							planoc.planoc,
							planoc.plcnome
						from
							planoc
                    ) plcmul1 on
						plcmul1.planoc = lac.lacplanoc
					left join (
						select
							count(*) as constalacmul,
							lacmul.lcmoriseq,
							lacmul.lcmdata
						from
							lacmul
						group by
							lacmul.lcmoriseq,
							lacmul.lcmdata
                    ) lcmul on
						lcmul.lcmoriseq = lac.lacseq
						and lcmul.lcmdata = lac.laclanca
					left join (
						select
							count(*) as constachquso1,
							chquso.chusequso,
							chquso.chudtuso
						from
							chquso
						where
							chquso.chusequen > 1
						group by
							chquso.chusequso,
							chquso.chudtuso
                    ) chq on
						chq.chusequso = lac.lacseq
						and chq.chudtuso = lac.laclanca
					left join (
						select
							count(*) as constachquso2,
							chquso.chusequso,
							chquso.chudtuso
						from
							chquso
						group by
							chquso.chusequso,
							chquso.chudtuso
                    ) chq2 on
						chq2.chusequso = lac.lacseq
						and chq2.chudtuso = lac.laclanca
					left join (
						select
							length(btrim(caiparam.pcxpccheq :: text)) as naopreenchidopcxpccheq,
							caiparam.pcxparam
						from
							caiparam
                    ) cprm on
						cprm.pcxparam = lac.lacdeposit
					left join (
						select
							prtipo1.prt1ccdeb,
							prtipo1.prt1pcdeb,
							prtipo1.prtdeposit
						from
							prtipo1
						where
							prtipo1.prtipo = 'CSF' :: bpchar
                    ) prt1 on
						prt1.prtdeposit = lac.lacdeposit
					left join (
						select
							prtipo1.prt1ccdeb,
							prtipo1.prt1pcdeb,
							prtipo1.prtdeposit
						from
							prtipo1
						where
							prtipo1.prtipo = 'CSF' :: bpchar
						order by
							prtipo1.prtdeposit
                    ) prt12 on
						prt12.prtdeposit = 0
					left join (
						select
							planoc.planoc,
							planoc.plcnome
						from
							planoc
                    ) plcmul2 on
						plcmul2.planoc = prt1.prt1pcdeb
					left join (
						select
							planoc.planoc,
							planoc.plcnome
						from
							planoc
                    ) plcmul3 on
						plcmul3.planoc = prt12.prt1pcdeb
            ) lan on
		t.controle = lan.laccontrol
		and t.titulo = lan.lactitulo
	where
		(
                t.tittipo = 'VND' :: bpchar
			and t.titdocto is not null
			and t.titdocto <> '' :: bpchar
			or t.tittipo <> 'VND' :: bpchar
            )
		and (
                t.titrecpag = any (array ['R'::bpchar,
		'P'::bpchar])
            )
    ) titulos_pagamentos
order by
	titulos_pagamentos.seq;

alter table
    pw_movtitulo owner to postgres;