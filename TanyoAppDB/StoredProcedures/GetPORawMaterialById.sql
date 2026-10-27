--TAN-4259 :: Portal: RM PO - Use Product PO functionality for RM PO (Enhance RM PO)
-- GetPORawMaterialById : 5-state status names (aligned with 03_ListPORawMaterials /
--                        02_Data_Fixers mapping: 1 Pending / 2 Approved / 3 Cancelled /
--                        4 Completed / 5 Material Ready) for header StatusName and item
--                        ItemStatusName; item JSON drops ExpectedDeliveryDate, adds
--                        TentativePOItemPickupDate and the nested PORawMaterialItemAttachments
--                        array (mirrors GetPOProductById).
-- NOTE: verify against the live SP before applying; confirm SubjectTypes row:
--       SELECT * FROM SubjectTypes WHERE SubjectName = 'PORawMaterials'

CREATE PROCEDURE [dbo].[GetPORawMaterialById]
(
     @PORawMaterialId BIGINT
    ,@TenantId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @VendorId BIGINT;

        SELECT @VendorId = p.VendorId
        FROM dbo.PORawMaterials p WITH (NOLOCK)
        WHERE p.PORawMaterialId = @PORawMaterialId
          AND p.TenantId = @TenantId
          AND p.IsDeleted = 0;

        SELECT p.PORawMaterialId
              ,p.VendorId
              ,v.VendorName
              ,p.PONumber
              ,p.OrderDate
              ,p.Status
              ,CASE p.Status
                    WHEN 1 THEN 'Pending'
                    WHEN 2 THEN 'Approved'
                    WHEN 3 THEN 'Cancelled'
                    WHEN 4 THEN 'Completed'
                    WHEN 5 THEN 'Material Ready'
                    ELSE ''
               END AS StatusName
              ,MAX(p.TotalAmount) AS TotalAmount
              ,(
                SELECT i.PORawMaterialItemId
                      ,i.RawMaterialId
                      ,rw.Title AS RawMaterialTitle
                      ,rw.ImagePath AS RawMaterialImage
                      ,i.Quantity
                      ,i.UnitPrice AS VendorRawMaterialPrice
                      ,i.Status
                      ,CASE i.Status
                            WHEN 1 THEN 'Pending'
                            WHEN 2 THEN 'Approved'
                            WHEN 3 THEN 'Cancelled'
                            WHEN 4 THEN 'Completed'
                            WHEN 5 THEN 'Material Ready'
                            ELSE ''
                       END AS ItemStatusName
                      ,i.TotalPrice AS TotalPrice
                      ,i.Remarks
                      ,i.TentativePOItemPickupDate
                      ,ISNULL(
                            (
                                SELECT prmia.PORawMaterialItemAttachmentId
                                      ,prmia.FileURL
                                      ,prmia.IsImage
                                FROM dbo.PORawMaterialItemAttachments prmia WITH (NOLOCK)
                                WHERE prmia.PORawMaterialItemId = i.PORawMaterialItemId
                                  AND prmia.IsDeleted = 0
                                FOR JSON PATH
                            ),
                            '[]'
                       ) AS PORawMaterialItemAttachments
                FROM dbo.PORawMaterialItems i WITH (NOLOCK)
                INNER JOIN RawMaterials rw WITH (NOLOCK) ON rw.RawMaterialId = i.RawMaterialId
                    AND rw.TenantId = @TenantId
                    AND rw.IsDeleted = 0
                WHERE i.PORawMaterialId = @PORawMaterialId
                FOR JSON PATH
               ) AS PORawMaterialItems
        FROM dbo.PORawMaterials p WITH (NOLOCK)
        INNER JOIN dbo.Vendors v WITH (NOLOCK) ON p.VendorId = v.VendorId
        WHERE p.PORawMaterialId = @PORawMaterialId
          AND p.TenantId = @TenantId
          AND p.IsDeleted = 0
        GROUP BY
            p.PORawMaterialId, p.VendorId, v.VendorName, p.PONumber, p.OrderDate, p.Status;
    END TRY
    BEGIN CATCH
    		DECLARE @ObjectName VARCHAR(500)
    			,@ErrorMsg VARCHAR(MAX);
    
    		SET @ObjectName = OBJECT_NAME(@@PROCID);
    		SET @ErrorMsg = ERROR_MESSAGE();
    
    		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
    			,@ErrorMsg = @ErrorMsg;
    END CATCH
END

GO

