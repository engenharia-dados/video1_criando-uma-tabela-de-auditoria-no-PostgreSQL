CREATE TABLE "TB_AUDITORIA" (
    schema TEXT not null,
    tabela TEXT not null,
    usuario TEXT,
    data timestamp with time zone not null default current_timestamp,
    acao TEXT NOT NULL check (acao in ('I','D','U')),
    dado_original TEXT,
    dado_novo TEXT,
    query TEXT
);

CREATE TABLE "TB_CLIENTE" (
    nome_cliente TEXT not null,
    id INTEGER not null,
    endereco TEXT not null
);

REVOKE all ON "TB_AUDITORIA" FROM public;

CREATE INDEX IDX_AUDIT_SCHEMA_TABELA
ON "TB_AUDITORIA" (((schema||'.'||tabela)::TEXT));

CREATE INDEX IDX_AUDIT_ACAO
ON "TB_AUDITORIA"(acao);

CREATE OR REPLACE FUNCTION FUNC_AUDITORIA() RETURNS trigger AS $body$
DECLARE
    v_old_data TEXT;
    v_new_data TEXT;
BEGIN

    if (TG_OP = 'UPDATE') then
        v_old_data := ROW(OLD.*);
        v_new_data := ROW(NEW.*);
        INSERT INTO "TB_AUDITORIA" (schema, tabela, usuario, acao, dado_original, dado_novo, query) 
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1), v_old_data, v_new_data, current_query());
        RETURN NEW;
    elsif (TG_OP = 'DELETE') then
        v_old_data := ROW(OLD.*);
        INSERT INTO "TB_AUDITORIA" (schema, tabela, usuario, acao, dado_original, query)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1), v_old_data, current_query());
        RETURN OLD;
    elsif (TG_OP = 'INSERT') then
        v_new_data := ROW(NEW.*);
        INSERT INTO "TB_AUDITORIA" (schema, tabela, usuario, acao, dado_novo, query)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1), v_new_data, current_query());
        RETURN NEW;
    else
        RAISE WARNING '[IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
        RETURN NULL;
    end if;

EXCEPTION
    WHEN data_exception THEN
        RAISE WARNING '[IF_MODIFIED_FUNC] - UDF ERROR [DATA EXCEPTION] - SQLSTATE: %, SQLERRM: %', SQLSTATE, SQLERRM;
        RETURN NULL;
    WHEN unique_violation THEN
        RAISE WARNING '[IF_MODIFIED_FUNC] - UDF ERROR [UNIQUE] - SQLSTATE: %, SQLERRM: %', SQLSTATE, SQLERRM;
        RETURN NULL;
    WHEN others THEN
        RAISE WARNING '[IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %', SQLSTATE, SQLERRM;
        RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
;

CREATE TRIGGER "TR_CLIENTE"
AFTER INSERT OR UPDATE OR DELETE ON "TB_CLIENTE"
FOR EACH ROW EXECUTE PROCEDURE FUNC_AUDITORIA();

SELECT * 
FROM "TB_AUDITORIA";

SELECT * 
FROM "TB_CLIENTE";

INSERT INTO "TB_CLIENTE" VALUES ('Tom', 100, 'Rua da Paz');

UPDATE "TB_CLIENTE" SET "id" = 150 WHERE "id" = 100;

DELETE FROM "TB_CLIENTE" WHERE "id" = 150;