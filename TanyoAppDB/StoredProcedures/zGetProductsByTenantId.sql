CREATE   PROCEDURE  [dbo].[zGetProductsByTenantId](
@TenantId INT,
@CategoryId BIGINT = NULL,
@ProductTitle nvarchar(4000)=NULL,
@ModelNo nvarchar(4000)=NULL,
@ProductQuantityDate datetimeoffset = NULL
)
WITH ENCRYPTION
AS
BEGIN 
SET NOCOUNT ON;
DECLARE @DEFAULT_IAMGE_PATH nvarchar(4000) = N'https://localhost:7253//images/no-coverimage.png';
SELECT 
    p.ProductQuantityId,
    p.ProductId, 
    t.ProductTitle,
    CAST(t.CategoryId AS bigint),
    t0.CategoryName,
    p.QuantityDate,
    CAST(0 AS bigint),
    CAST(p.MinimumLimit AS bigint),
    t.ModelNo,
    p.LastModifiedBy,
    a.Id,
    a.AccessFailedCount,
    a.CommissionPer, 
    a.ConcurrencyStamp,
    a.Email, 
    a.EmailConfirmed,
    a.FirstName,
    a.IsActive,
    a.IsDeleted,
    a.IsNewUser,
    a.LastName, 
    a.LockoutEnabled, 
    a.LockoutEnd,
    a.MacAddress, 
    a.MobileDeviceId,
    a.NormalizedEmail,
    a.NormalizedUserName, 
    a.PasswordHash, 
    a.PhoneNumber, 
    a.PhoneNumberConfirmed, 
    a.RegisteredFCMToken,
    a.SecurityStamp,
    a.TwoFactorEnabled, 
    a.UserId,
    a.UserName,
    p.LastModifiedDate,
    p.LastModifiedUTCDate,

	 -- Product Image Path Logic
    CASE
        WHEN t.CoverImage IS NOT NULL AND LTRIM(RTRIM(t.CoverImage)) <> '' THEN t.CoverImage
        ELSE @DEFAULT_IAMGE_PATH
    END AS ProductImagePath,

	CAST(ISNULL(StockDetails.InStock, 0) AS INT) AS InStock,
    CAST(ISNULL(StockDetails.Inquiry, 0) AS INT) AS Inquiry,
    CAST(ISNULL(StockDetails.ReadyToDelivered, 0) AS INT) AS ReadyToDelivered,
    CAST(ISNULL(StockDetails.OnHold, 0) AS INT) AS OnHold

	FROM ProductQuantities AS p
	-- Joining Products Table
INNER JOIN (
    SELECT p0.ProductId, p0.CategoryId, p0.ModelNo, p0.ProductTitle, p0.CoverImage
 FROM Products AS p0
   WHERE (p0.TenantId =@TenantId OR @TenantId IS NULL) AND p0.Status <> 3
	) AS t ON p.ProductId = t.ProductId

	-- Joining Categories Table
INNER JOIN (
    SELECT c.CategoryId, c.CategoryName
  FROM Categories AS c
    WHERE c.IsDeleted = CAST(0 AS bit)
    AND (c.TenantId = @TenantId or @TenantId is null)
    AND c.CategoryTypeId = CAST(1 AS bigint)
) AS t0 ON CAST(t.CategoryId AS bigint) = t0.CategoryId

-- Joining Users Table
INNER JOIN AspNetUsers AS a ON p.LastModifiedBy = CAST(a.UserId AS bigint)

-- Fetching Product Image
--OUTER APPLY (
--    SELECT TOP(1) p1.ProductImageID, p1.ImagePath
--    FROM ProductImages AS p1
--    WHERE p1.IsCover = CAST(1 AS bit) AND t.ProductId = p1.ProductId
--    ORDER BY p1.CreatedDate
--) AS t1


-- Joining Product Stock Details from the Subquery
LEFT JOIN (
    SELECT 
        p.ProductId,
        SUM(ISNULL(ia.Quantity, 0)) AS InStock,
        SUM(ISNULL(inquiry.Qty, 0)) AS Inquiry,
        SUM(ISNULL(ReadyToDelivered.Qty, 0)) AS ReadyToDelivered,
        SUM(ISNULL(OnHold.Qty, 0)) AS OnHold
    FROM Products p WITH (NOLOCK)
    
    LEFT JOIN ProductQuantities ia WITH (NOLOCK) 
        ON p.ProductId = ia.ProductId
    
	--select * from  Su
    LEFT JOIN (
        SELECT vi.SubjectId AS ProductId, SUM(vi.Quantity) AS Qty
        FROM vw_InquiryItems vi WITH (NOLOCK)
        WHERE vi.TenantId = @TenantId
        
        
		AND vi.SubjectTypeId = (
            SELECT SubjectTypeId FROM SubjectTypes WITH (NOLOCK)
            WHERE SubjectTypeName = 'Products'
            AND TenantId =@TenantId
            AND IsDeleted = 0
        )
        GROUP BY vi.SubjectId
    ) AS inquiry ON inquiry.ProductId = p.ProductId

    LEFT JOIN (
        SELECT vi.SubjectId AS ProductId, SUM(vi.Quantity) AS Qty
        FROM vw_ReadyToDeliveredItems vi WITH (NOLOCK)
        WHERE vi.TenantId = @TenantId
        AND vi.SubjectTypeId = (
            SELECT SubjectTypeId FROM SubjectTypes WITH (NOLOCK)
            WHERE SubjectTypeName = 'Products'
            AND TenantId = @TenantId
            AND IsDeleted = 0
        )
        GROUP BY vi.SubjectId
    ) AS ReadyToDelivered ON ReadyToDelivered.ProductId = p.ProductId

	--SELECT * FROM vw_HoldItems
    LEFT JOIN (
        SELECT vi.SubjectId AS ProductId, SUM(vi.Quantity) AS Qty
        FROM vw_HoldItems vi WITH (NOLOCK)
        WHERE vi.TenantId = @TenantId
        AND vi.HoldUptoDate > SYSDATETIMEOFFSET()
        GROUP BY vi.SubjectId
    ) AS OnHold ON OnHold.ProductId = p.ProductId
    
    WHERE p.TenantId = @TenantId
    GROUP BY p.ProductId
) AS StockDetails ON p.ProductId = StockDetails.ProductId

WHERE 
    (@CategoryId IS NULL OR CAST(t.CategoryId AS bigint) = @CategoryId)
AND (ModelNo IS NULL OR t.ModelNo LIKE ModelNo ESCAPE N'\')
AND (@ProductTitle IS NULL OR t.ProductTitle LIKE @ProductTitle ESCAPE N'\')
AND (@ProductQuantityDate IS NULL OR p.QuantityDate = @ProductQuantityDate)

END

GO

