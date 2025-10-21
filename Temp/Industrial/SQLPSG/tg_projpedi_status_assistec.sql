    DROP TRIGGER IF EXISTS tg_projpedi_status_assistec ON projped1;
    create trigger tg_projpedi_status_assistec
      after insert or update or delete
      on projped1
      for each row
      execute procedure fn_projpedi_status_assistec();