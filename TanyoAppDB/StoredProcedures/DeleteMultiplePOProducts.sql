CREATE   PROCEDURE [dbo].[DeleteMultiplePOProducts]
(
    @POProductIds NVARCHAR(MAX),
    @UserID INT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        ------------------------------------------------------------
        -- Validation
        ------------------------------------------------------------
        IF ISNULL(LTRIM(RTRIM(@POProductIds)), '') = ''
        BEGIN
            SELECT 0 AS [Status],
                   'Please select at least one PO.' AS [Message];
            RETURN;
        END

        ------------------------------------------------------------
        -- Temp Table
        ------------------------------------------------------------
        CREATE TABLE #POProducts
        (
            POProductId BIGINT PRIMARY KEY
        );

        INSERT INTO #POProducts (POProductId)
        SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS BIGINT)
        FROM STRING_SPLIT(@POProductIds, ',')
        WHERE TRY_CAST(value AS BIGINT) IS NOT NULL;
        
         -- 1. Validate Product
        IF NOT EXISTS (
            SELECT 1
            FROM #POProducts T
            INNER JOIN dbo.POProducts POP WITH (NOLOCK)
                ON POP.POProductId = T.POProductId
        )
        BEGIN
            SELECT CAST(0 AS BIT) AS [Status],
                'Product not found.' AS [Message];
            RETURN;
        END

        -- 2. Validate if product is already deleted
        IF EXISTS (
            SELECT 1
            FROM dbo.POProducts POP WITH (NOLOCK)
            INNER JOIN #POProducts T ON POP.POProductId = T.POProductId
            WHERE POP.IsDeleted = 1
        )
        BEGIN
            SELECT CAST(0 AS BIT) AS [Status],
                'This product has already been deleted.' AS [Message];
            RETURN;
        END

        ------------------------------------------------------------
        -- Soft Delete Products
        ------------------------------------------------------------
        UPDATE POP
        SET
            POP.IsDeleted = 1,
            POP.UpdatedBy = @UserID,
            POP.UpdatedDate = GETDATE(),
            POP.UpdatedUTCDate = GETUTCDATE()
        FROM POProducts POP
        INNER JOIN #POProducts T
            ON POP.POProductId = T.POProductId;

        ------------------------------------------------------------
        -- Success
        ------------------------------------------------------------
        SELECT 1 AS [Status],
               'Selected PO records deleted successfully.' AS [Message];

    END TRY
    BEGIN CATCH

        SELECT 0 AS [Status],
               ERROR_MESSAGE() AS [Message];

    END CATCH
END

GO

