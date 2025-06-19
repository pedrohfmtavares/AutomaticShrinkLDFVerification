CREATE OR ALTER PROCEDURE SP_CLEAN_LOG

AS

DROP TABLE IF EXISTS #VALIDACAO_DISCO_DE_LOG

SELECT DISTINCT
    VS.volume_mount_point [Montagem] ,
	VS.logical_volume_name AS [Volume],
    CAST(( CAST(VS.available_bytes AS DECIMAL(19, 2)) / CAST(VS.total_bytes AS DECIMAL(19, 2)) * 100 ) AS DECIMAL(10, 2)) AS [Espaço Disponível]
	INTO #VALIDACAO_DISCO_DE_LOG
FROM
    sys.master_files AS MF
    CROSS APPLY [sys].[dm_os_volume_stats](MF.database_id, MF.file_id) AS VS
WHERE
    CAST(VS.available_bytes AS DECIMAL(19, 2)) / CAST(VS.total_bytes AS DECIMAL(19, 2)) * 100 < 100;

-- Montagem = (C:, E:, L: etc) Volume = Name of the disk
DECLARE @espaco decimal(19,2) = (SELECT [Espaço Disponível] FROM #VALIDACAO_DISCO_DE_LOG WHERE Montagem LIKE '%C%' AND Volume LIKE '%OS%') 

if @espaco <= 20.0 -- Aqui você coloca quantos % o disco pode chegar sem realizar Shrinks de LOG

BEGIN

EXEC sp_MSforeachdb '
USE [?];

IF DB_ID() > 4
AND EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = DB_NAME()
      AND state_desc = ''ONLINE''
      AND log_reuse_wait_desc = ''NOTHING''
      AND is_read_only = 0
)
BEGIN
    -- Verifica se a base está em um AG e é primária, ou se não está em AG
    IF EXISTS (
        SELECT 1
        FROM sys.dm_hadr_database_replica_states drs
        WHERE drs.database_id = DB_ID()
          AND drs.is_local = 1
          AND drs.is_primary_replica = 1
    )
    BEGIN
        DECLARE @LogFileName sysname;

        SELECT TOP 1 @LogFileName = mf.name
        FROM sys.master_files mf
        WHERE mf.database_id = DB_ID()
          AND mf.type = 1 -- Arquivo de Log
          AND mf.physical_name LIKE ''C:\%'' --AQUI VOCÊ COLOCA O DISCO OU DIRETÓRIO QUE PREFERIR

        IF @LogFileName IS NOT NULL
        BEGIN
            PRINT ''Shrinking log of database: [?]'';
            DBCC SHRINKFILE(@LogFileName, 0);
        END
    END
END
';


END

DROP TABLE IF EXISTS #VALIDACAO_DISCO_DE_LOG