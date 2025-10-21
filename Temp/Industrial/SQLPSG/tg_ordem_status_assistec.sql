    DROP TRIGGER IF EXISTS tg_ordem_status_assistec ON ordem;
    create trigger tg_ordem_status_assistec
      after insert or update or delete
      on ordem
      for each row
      execute procedure fn_ordem_status_assistec();