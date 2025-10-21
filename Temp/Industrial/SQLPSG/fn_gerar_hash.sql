-- Function: fn_gerar_hash(character, character, character, character, character, character, character, character)

-- DROP FUNCTION fn_gerar_hash(character, character, character, character, character, character, character, character);

CREATE OR REPLACE FUNCTION fn_gerar_hash(pproduto character, pengestver character, pgravahash character, pnivelzero character, pgenerico character, pconfatmed character, pusuario character, pcalcgeral character)
  RETURNS text AS
$BODY$
DECLARE
	r_estrutura record;	
	r_dimensao record;	
	r_medidas record;	
	vhash character(32);	
	vhash_filho character(32);	
	vtexto text;
	vtexto_nivelzero text;	
	vretorno text;
	vdimcodigo char(32);
	vfilcod char(16);
	vpaicod char(16);	
	vpaitmp char(16);
    vversao_algoritmo_hash numeric;
BEGIN
    vversao_algoritmo_hash = 1;
	--RAISE NOTICE 'fn_gerar_hash(%,%,%,%,%,%,%,%)', pproduto ,    pengestver ,    pgravahash ,    pnivelzero ,    pgenerico ,    pconfatmed ,    pusuario ,    pcalcgeral; 
	
	vtexto = '';
	--vtexto_nivelzero = '"zero->';
	
    for r_medidas in (
		select m.prostatus,
			case when proconx = 'S' then
				trim(probrcom::character(10))  || trim(proficom::character(10))
			else
				'00'
			end
			||
			case when  procony = 'S' then
				trim(probrlar::character(10))  || trim(profilar::character(10))
			else
				'00'
			end
			||
			case when proconz = 'S' then
				trim(probresp::character(10))  || trim(profiesp::character(10))
			else
				'00'
			end as medidas_texto
		 
		from produto m 
		where m.produto = pproduto
	) loop
	
		vtexto_nivelzero = r_medidas.medidas_texto;

		if r_medidas.prostatus <> 'A' then
			RAISE NOTICE 'Produto % INATIVO no calculo de HASH.', pproduto 
			USING HINT = 'Produto inativo nao pode ser utilizado na estrutura mas tentou calcular HASH: ' || pproduto;
		end if;
	end loop;	

	vtexto_nivelzero = vtexto_nivelzero ||'<-zero"';
    
	vpaicod = pproduto;		
	vpaitmp = (select trim(c1.cprefpba) from confref c1 where c1.cprefpco = pproduto limit 1);
	if length(vpaitmp) > 0 then
		vpaicod = vpaitmp;
	end if;

	for r_estrutura in (
		select e.*, p.proorigem as origem_filho, p.prostatus as status_filho,			
			/*(
				select  a.esthash 
				from estrutur a 
				where trim(esthash) <> ''
					and a.estproduto = e.estfilho
					limit 1
			) as hash_filho, provavelmente esta leitura vai estar com o hash desatualizado se o filho se repetir*/
			case when p.proorigem = 'F' then
				coalesce((select trim(c2.cprefpba) from confref c2 where c2.cprefpco = e.estfilho limit 1), e.estfilho) 
			else 
				e.estfilho
			end as vfilcod
		from estrutur e
		left join ( select pro.produto, pro.proorigem, pro.prostatus from produto pro) as p on p.produto = e.estfilho
		where e.estproduto = pproduto
			and e.estproduto <> e.estfilho
		
		order by e.estfilho
        ) loop
		
		if r_estrutura.status_filho <> 'A' then 
		    RAISE NOTICE 'Produto componente % INATIVO no calculo de HASH. Produto pai %', r_estrutura.estfilho, vpaicod 
		    USING HINT = 'Produto componente inativo nao pode ser utilizado na estrutura mas tentou calcular HASH: ' || r_estrutura.estfilho || 'Filho de ' || vpaicod;
		  end if;	

		--a consulta ja retorna esta informacao tratada
		vfilcod = r_estrutura.vfilcod;

		vtexto = trim(vtexto) || trim(vpaicod);
		vtexto = trim(vtexto) || trim(vfilcod);
		vtexto = trim(vtexto) || trim(r_estrutura.fase::character(2)) || trim(r_estrutura.estusamed) || trim(r_estrutura.estarea::character(8));
		vtexto = trim(vtexto) || trim(r_estrutura.estqtduso::character(15)) || trim(r_estrutura.estpriemb::character(10)) || trim(r_estrutura.estinfadi);

		-- Se ligacao de estrutura usa medidas
		If r_estrutura.estusamed = 'S' and pgenerico <> 'S' then
		
			vdimcodigo = (rpad(r_estrutura.estproduto,16,' ') || r_estrutura.estfilho)::character(32);

			for r_dimensao in (select * from dimensao d where d.dimcodigo = vdimcodigo order by dimcodigo, dimseq) loop

				if pconfatmed = 'S' then
					vtexto = trim(vtexto) || trim(r_dimensao.dimquanti::character(15)) || trim(r_dimensao.dimbrucomp::character(10));
				else
					vtexto = trim(vtexto) || trim(r_dimensao.dimdescri) || trim(r_dimensao.dimquanti::character(15)) || trim(r_dimensao.dimbrucomp::character(10));
				end if;
					
				vtexto = trim(vtexto) || trim(r_dimensao.dimbrularg::character(10)) || trim(r_dimensao.dimbruespe::character(10)) || trim(r_dimensao.dimfincomp::character(10));
				vtexto = trim(vtexto) || trim(r_dimensao.dimfinlarg::character(10)) || trim(r_dimensao.dimfinespe::character(10)) || trim(r_dimensao.dimpercent::character(5));
				vtexto = trim(vtexto) || trim(r_dimensao.dimcorte) || trim(r_dimensao.dimperx::character(5)) || trim(r_dimensao.dimpery::character(5)) || trim(r_dimensao.dimperz::character(5));
				
			end loop;

		End if;

		-- Desce estrutura se item for fabricado	
		If r_estrutura.origem_filho = 'F' then	
			vhash_filho = '';

            /*Busca o ultimo hash atualizado do filho (desatualizados e versao diferente nao sao reaproveitados)*/
			select  a.esthash 	
            from estrutur a 
            where a.estproduto = r_estrutura.estfilho
                and trim(esthash) <> ''
                and estnivhash = vversao_algoritmo_hash
                and (estdthash || ' ' || esthrhash)::TIMESTAMP >= (estdtalt || ' ' || esthralt)::TIMESTAMP
            limit 1 
            into vhash_filho;
			
            /* Vai gerar hash do filho se ele nao estiver gerado (ou desatualizado) ou se nao eh para gravar. 
            Pois se *nao eh para gravar* e apenas comparar, dai serao poucos casos e pode gerar para a estrutura inteira.
            Assim tem certeza que o hash foi calculado corretamente e nao reaproveitou nenhum hash errado/desatualziado. */
			if  pgravahash = 'N' OR nullif(trim(vhash_filho), '') is null then
					
				vretorno = fn_gerar_hash(r_estrutura.estfilho, pengestver, pgravahash, 'N'/*nao faz diferenca*/, pgenerico, pconfatmed, 'USUARIO'/*nao faz diferenca*/, 'N'/*nao faz diferenca*/);
				--RAISE NOTICE 'Produto % gerado: %', r_estrutura.estfilho , vretorno;
			else
				vretorno = vhash_filho;
				--RAISE NOTICE 'Produto % ja calculado : %', r_estrutura.estfilho , vretorno;
			end if;
			
			if length(trim(vretorno)) > 0 then
				vtexto = trim(vtexto) || trim(vretorno);
			end if;

		End if;
		
	end loop;

	vtexto = trim(vtexto_nivelzero) || trim(vtexto);

	vhash = md5(vtexto);

	if pgravahash = 'S' then

        /*Atualiza na estrutura o hash do produto, onde ele for diferente ou de outra versao*/
		update estrutur
			set esthash = vhash,
            estnivhash = vversao_algoritmo_hash,
            estdthash = current_date,
			esthrhash = substring(current_time::text, 1, 8)

		where estproduto = pproduto
            and (
                esthash <> vhash
                or estnivhash <> vversao_algoritmo_hash
                OR estdthash <> current_date
			    OR esthrhash <> substring(current_time::text, 1, 8)
            );
        

		--RAISE NOTICE 'update estrutur set esthash = vhash where estproduto = % and esthash <> %;', pproduto, vhash;
		
	end if;

	--RAISE NOTICE 'Produto % calculado: %', pproduto, vhash;	

	return vhash;
	
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_gerar_hash(character, character, character, character, character, character, character, character)
  OWNER TO postgres;
