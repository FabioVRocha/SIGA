    DROP TRIGGER IF EXISTS tg_expsimpl_status_assistec ON prjexsi1;
    create trigger tg_expsimpl_status_assistec
      after insert or update or delete
      on prjexsi1
      for each row
      execute procedure fn_expsimpl_status_assistec();