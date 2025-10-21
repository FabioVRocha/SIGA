    DROP TRIGGER IF EXISTS tg_assistec_status_assistec ON assistec;
    create trigger tg_assistec_status_assistec
      after insert or update or delete
      on assistec
      for each row
      execute procedure fn_assistec_status_assistec();