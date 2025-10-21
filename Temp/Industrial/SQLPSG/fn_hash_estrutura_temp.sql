-- Function: fn_hash_estrutura_temp(character, character, bigint, character, character, character)

-- DROP FUNCTION fn_hash_estrutura_temp(character, character, bigint, character, character, character);

CREATE OR REPLACE FUNCTION fn_hash_estrutura_temp(pusuario character, pproduto character, pseqpai bigint, pgravahash character, pnivelzero character, pconfatmed character)
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

BEGIN
	
	vtexto = '';
	--vtexto_nivelzero = '#zero->';
	
    for r_medidas in (
        --PRODUTO SEMPRE CONSIDERADO COMO ATIVO NA TEMPORARIA PARA MANTER O CODIGO IGUAL AO fn_gerar_hash
        --IDEIA: fn_gerar_hash poder receber um set de hash para geracao
		select 'A'::character(1) as prostatus,
			case when tdpcox = 'S' then
				trim(tdpbrx::character(10))  || trim(tdpfix::character(10))
			else
				'00'
			end
			||
			case when  tdpcoy = 'S' then
				trim(tdpbry::character(10))  || trim(tdpfiy::character(10))
			else
				'00'
			end
			||
			case when tdpcoz = 'S' then
				trim(tdpbrz::character(10))  || trim(tdpfiz::character(10))
			else
				'00'
			end as medidas_texto
		 
		from umprodim m 
        where m.tdpusu = pusuario 
            and m.tdppro = pproduto
            and m.tpdspa = pseqpai order by tdppro
	) loop
	
		vtexto_nivelzero = r_medidas.medidas_texto;

		if r_medidas.prostatus <> 'A' then
			RAISE NOTICE 'Produto % INATIVO no calculo de HASH.', pproduto 
			USING HINT = 'Produto inativo nao pode ser utilizado na estrutura mas tentou calcular HASH: ' || pproduto;
		end if;
	end loop;	

	vtexto_nivelzero = vtexto_nivelzero ||'<-zero#';
    
	vpaicod = pproduto;		
	vpaitmp = (select trim(c1.cprefpba) from confref c1 where c1.cprefpco = pproduto limit 1);
	if length(vpaitmp) > 0 then
		vpaicod = vpaitmp;
	end if;

	for r_estrutura in (
		select e.*, p.proorigem as origem_filho, p.prostatus as status_filho,			
			case when p.proorigem = 'F' then
				coalesce((select trim(c2.cprefpba) from confref c2 where c2.cprefpco = e.tesfilcod limit 1), e.tesfilcod) 
			else 
				e.tesfilcod
			end as vfilcod
		from umestemp e
		left join ( select pro.produto, pro.proorigem, pro.prostatus from produto pro) as p on p.produto = e.tesfilcod
		where e.tesusuario = pusuario
            and e.tespaiseq = pseqpai
            and e.tesprocod = pproduto
			--isso so vai acontecer em caso de o produto estar ligado diretamente com ele mesmo, nao resolve se um filho dele estiver ligado com ele
            and e.tesprocod <> e.tesfilcod
		
		order by e.tesfilcod
        ) loop
		
		if r_estrutura.status_filho <> 'A' then 
		    RAISE NOTICE 'Produto componente % INATIVO no calculo de HASH. Produto pai %', r_estrutura.tesfilcod, vpaicod 
		    USING HINT = 'Produto componente inativo nao pode ser utilizado na estrutura mas tentou calcular HASH: ' || r_estrutura.tesfilcod || 'Filho de ' || vpaicod;
		  end if;	

		--a consulta ja retorna esta informacao tratada
		vfilcod = r_estrutura.vfilcod;

		vtexto = trim(vtexto) || trim(vpaicod);
		vtexto = trim(vtexto) || trim(vfilcod);
		vtexto = trim(vtexto) || trim(r_estrutura.tesfaspro::character(2)) || trim(r_estrutura.tesusamed) || trim(r_estrutura.tesproare::character(8));
		vtexto = trim(vtexto) || trim(r_estrutura.tesquauso::character(15)) || trim(r_estrutura.tespriemb::character(10)) || trim(r_estrutura.tesinfadi);

		-- Se ligacao de estrutura usa medidas
		If r_estrutura.tesusamed = 'S' then
		
			vdimcodigo = (rpad(r_estrutura.tesprocod,16,' ') || r_estrutura.tesfilcod)::character(32);

			for r_dimensao in (select * from umdimtem d where d.tdiusu = pusuario and d.tdicod = vdimcodigo
                and d.tdispa = pseqpai and d.tdisfi = r_estrutura.tesfilseq order by d.tdicod, d.tdiseq) loop

				if pconfatmed = 'S' then
					vtexto = trim(vtexto) || trim(r_dimensao.tdiqtd::character(15)) || trim(r_dimensao.tdibco::character(10));
				else
					vtexto = trim(vtexto) || trim(r_dimensao.tdides) || trim(r_dimensao.tdiqtd::character(15)) || trim(r_dimensao.tdibco::character(10));
				end if;
					
				vtexto = trim(vtexto) || trim(r_dimensao.tdibla::character(10)) || trim(r_dimensao.tdibes::character(10)) || trim(r_dimensao.tdifco::character(10));
				vtexto = trim(vtexto) || trim(r_dimensao.tdifla::character(10)) || trim(r_dimensao.tdifes::character(10)) || trim(r_dimensao.tdiper::character(5));
				vtexto = trim(vtexto) || trim(r_dimensao.tdicor) || trim(r_dimensao.tdipex::character(5)) || trim(r_dimensao.tdipey::character(5)) || trim(r_dimensao.tdipez::character(5));
				
			end loop;

		End if;

		-- Desce estrutura se item for fabricado	
		If r_estrutura.origem_filho = 'F' then	
			vhash_filho = '';
            --NUNCA GRAVA HASH NA TEMPORARIA! impede o reaproveitamento, talvez poderamos pensar em gravar. Para isso precisa filtrar a leitura das sequencias corretas?
			--select  a.esthash 	from umestemp a where trim(esthash) <> ''and a.tesprocod = r_estrutura.tesfilcod limit 1 into vhash_filho;
			
		
			if  pgravahash = 'N' OR nullif(trim(vhash_filho), '') is null then
				--Sempre vai entrar aqui pois na temporaria nao grava hash	
				vretorno = fn_hash_estrutura_temp(pusuario, r_estrutura.tesfilcod, pseqpai, pgravahash, ''/*nao utilizado*/, pconfatmed);
				--RAISE NOTICE 'Produto % gerado: %', r_estrutura.tesfilcod , vretorno;
			else
				vretorno = vhash_filho;
				--RAISE NOTICE 'Produto % ja calculado : %', r_estrutura.tesfilcod , vretorno;
			end if;
			
			if length(trim(vretorno)) > 0 then
				vtexto = trim(vtexto) || trim(vretorno);
			end if;

		End if;
		
	end loop;

	vtexto = trim(vtexto_nivelzero) || trim(vtexto);

	vhash = md5(vtexto);

	-- if pgravahash = 'S' then

	-- 	update estrutur
	-- 		set esthash = vhash
	-- 	where tesprocod = pproduto
	-- 	and esthash <> vhash;
		
	-- end if;

	--RAISE NOTICE 'Produto % calculado: %', pproduto, vhash;	

	return vhash;
	
END;$BODY$
  LANGUAGE plpgsql VOLATILE --SECURITY DEFINER
  COST 100;
ALTER FUNCTION fn_hash_estrutura_temp(character, character, bigint, character, character, character)
  OWNER TO postgres;
