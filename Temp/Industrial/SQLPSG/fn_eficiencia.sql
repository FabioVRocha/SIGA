-- Function: fn_eficiencia(integer, integer)

-- DROP FUNCTION fn_eficiencia(integer, integer);

CREATE OR REPLACE FUNCTION fn_eficiencia(v_funcionario integer, v_ordem integer)
  RETURNS numeric AS
$BODY$
declare	
    v_eficiencia numeric(15,4);
begin	
	v_eficiencia := (select 
	Round(Sum(Round(((((Round(r.RPRTMPRES,0 )*60) + 
	(r.RPRTMPRES - Round(r.RPRTMPRES,0))*100) / r.rprqtde + r.rprtmpset)*p.plaquant) ))   /	
    Sum(Round(p.plahoras,0 ) * 60 + ( (p.plahoras) - Round(p.plahoras,0 )) * 100 )*100,0)
	from planilha p
	inner join respror r
	on r.rprordem = p.plaordem 
	and r.rprproce = p.plaproc 	
	where p.plaordem = v_ordem 
	and (p.plafuncion = v_funcionario or  v_funcionario = 0)
	and p.plaquant > 0
	and p.plahoras > 0
	and r.RPRQTDE > 0
	and r.RPRTMPRES > 0);
	return v_eficiencia;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE 
  COST 100;

ALTER FUNCTION fn_eficiencia(integer, integer)
  OWNER TO postgres;

  
