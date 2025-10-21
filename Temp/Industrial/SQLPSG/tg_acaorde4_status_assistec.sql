    DROP TRIGGER IF EXISTS tg_acaorde4_status_assistec ON acaorde4;
    create trigger tg_acaorde4_status_assistec
      after insert or update or delete
      on acaorde4
      for each row
      execute procedure fn_acaorde4_status_assistec();