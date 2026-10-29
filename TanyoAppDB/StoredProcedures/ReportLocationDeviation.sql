CREATE OR ALTER PROCEDURE [dbo].[ReportLocationDeviation]  
    @TenantId BIGINT,  
    @LocationId BIGINT,  
    @FromDate DATE = NULL,  
    @ToDate DATE = NULL,  
    @UserId BIGINT = NULL,  
    @GeofenceRadiusMeters FLOAT = 500,  
    @AttendanceStatus INT = 0,  
    @PunchType INT = 0,  
    @PageIndex INT = 1,  
    @PageSize INT = 10,  
    @SortBy VARCHAR(50) = 'PunchInDateTime',  
    @SortOrder VARCHAR(4) = 'DESC'  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
  
    BEGIN TRY  
  
        /* Default invalid geofence radius */  
        IF @GeofenceRadiusMeters IS NULL  
           OR @GeofenceRadiusMeters <= 0  
        BEGIN  
            SET @GeofenceRadiusMeters = 500;  
        END;  
  
        /* Validate pagination parameters */  
        IF @PageIndex IS NULL OR @PageIndex < 1  
            SET @PageIndex = 1;  
  
        IF @PageSize IS NULL OR @PageSize < 1  
            SET @PageSize = 10;  
  
        IF @PageSize > 500  
            SET @PageSize = 500;  
  
        /* Validate sorting parameters */  
        SET @SortBy = LTRIM(RTRIM(ISNULL(@SortBy, '')));  
        SET @SortOrder = UPPER(LTRIM(RTRIM(ISNULL(@SortOrder, ''))));  
  
        IF @SortBy NOT IN  
        (  
            'EmployeeName',  
            'PunchInDateTime',  
            'PunchInDistanceMeters'  
        )  
        BEGIN  
            SET @SortBy = 'PunchInDateTime';  
        END;  
  
        IF @SortOrder NOT IN ('ASC', 'DESC')  
        BEGIN  
            SET @SortOrder = 'DESC';  
        END;  
  
        DECLARE  
            @RefLat FLOAT,  
            @RefLng FLOAT,  
            @RefPoint GEOGRAPHY = NULL;  
  
        SELECT  
            @RefLat = TRY_CAST(Latitude AS FLOAT),  
            @RefLng = TRY_CAST(Longitude AS FLOAT)  
        FROM dbo.Locations WITH (NOLOCK)  
        WHERE LocationID = @LocationId  
          AND TenantId = @TenantId  
          AND IsDeleted = 0;  
  
        /* Create the geography point only for valid coordinates */  
        IF @RefLat BETWEEN -90 AND 90  
           AND @RefLng BETWEEN -180 AND 180  
        BEGIN  
            SET @RefPoint = geography::Point(  
                @RefLat,  
                @RefLng,  
                4326  
            );  
        END;  
  
        /* Exclusive upper date boundary */  
        DECLARE @ToDateExclusive DATE;  
  
        IF @ToDate IS NOT NULL  
        BEGIN  
            SET @ToDateExclusive = DATEADD(DAY, 1, @ToDate);  
        END;  
  
        SELECT  
            AttendanceDeviation.*,  
            COUNT(1) OVER () AS TotalCount  
        FROM  
        (  
            SELECT  
                a.AttendanceId,  
                a.UserId,  
                LTRIM(RTRIM(  
                    CONCAT(u.FirstName, ' ', u.LastName)  
                )) AS EmployeeName,  
  
                a.StartDate AS PunchInDateTime,  
                a.InLatitude AS PunchInLatitude,  
                a.InLongitude AS PunchInLongitude,  
                dist.InDist AS PunchInDistanceMeters,  
  
                CASE  
                    WHEN dist.InDist IS NULL THEN 0  
                    WHEN dist.InDist <= @GeofenceRadiusMeters THEN 1  
                    ELSE 2  
                END AS PunchInStatus,  
  
                a.EndDate AS PunchOutDateTime,  
                a.OutLatitude AS PunchOutLatitude,  
                a.OutLongitude AS PunchOutLongitude,  
                dist.OutDist AS PunchOutDistanceMeters,  
  
                CASE  
                    WHEN a.EndDate IS NULL THEN 0  
                    WHEN dist.OutDist IS NULL THEN 0  
                    WHEN dist.OutDist <= @GeofenceRadiusMeters THEN 1  
                    ELSE 2  
                END AS PunchOutStatus  
  
            FROM dbo.Attendance AS a WITH (NOLOCK)  
  
            INNER JOIN dbo.AspNetUsers AS u WITH (NOLOCK)  
                ON u.UserId = a.UserId  
  
            INNER JOIN dbo.UserTenantMapping AS utm WITH (NOLOCK)  
                ON utm.UserId = u.UserId  
               AND utm.TenantId = @TenantId  
  
            CROSS APPLY  
            (  
                SELECT  
 TRY_CAST(a.InLatitude AS FLOAT) AS InLat,  
                    TRY_CAST(a.InLongitude AS FLOAT) AS InLng,  
                    TRY_CAST(a.OutLatitude AS FLOAT) AS OutLat,  
                    TRY_CAST(a.OutLongitude AS FLOAT) AS OutLng  
            ) AS c  
  
            CROSS APPLY  
            (  
                SELECT  
                    CASE  
                        WHEN @RefPoint IS NOT NULL  
                         AND c.InLat BETWEEN -90 AND 90  
                         AND c.InLng BETWEEN -180 AND 180  
                        THEN geography::Point(  
                            c.InLat,  
                            c.InLng,  
                            4326  
                        ).STDistance(@RefPoint)  
                        ELSE NULL  
                    END AS InDist,  
  
                    CASE  
                        WHEN @RefPoint IS NOT NULL  
                         AND c.OutLat BETWEEN -90 AND 90  
                         AND c.OutLng BETWEEN -180 AND 180  
                        THEN geography::Point(  
                            c.OutLat,  
                            c.OutLng,  
                            4326  
                        ).STDistance(@RefPoint)  
                        ELSE NULL  
                    END AS OutDist  
            ) AS dist  
  
            WHERE utm.TenantId = @TenantId  
              AND a.Type = 0  
  
              AND  
              (  
                  @UserId IS NULL  
                  OR @UserId = -1  
                  OR a.UserId = @UserId  
              )  
  
              AND  
              (  
                  @FromDate IS NULL  
                  OR a.StartDate >= @FromDate  
              )  
  
              AND  
              (  
                  @ToDateExclusive IS NULL  
                  OR a.StartDate < @ToDateExclusive  
              )  
  
        ) AS AttendanceDeviation  
  
        WHERE  
            /* Attendance Status:  
               0 = All  
               1 = Inside  
               2 = Outside  
            */  
            (  
                @AttendanceStatus = 0  
  
                OR  
                (  
                    @AttendanceStatus = 1  
                    AND  
                    (  
                        AttendanceDeviation.PunchInStatus = 1  
                        OR AttendanceDeviation.PunchOutStatus = 1  
                    )  
                    AND AttendanceDeviation.PunchInStatus <> 2  
                    AND AttendanceDeviation.PunchOutStatus <> 2  
                )  
  
                OR  
                (  
                    @AttendanceStatus = 2  
                    AND  
                    (  
                        AttendanceDeviation.PunchInStatus = 2  
                        OR AttendanceDeviation.PunchOutStatus = 2  
                    )  
                )  
            )  
  
            /* Punch Type:  
               0 = All  
               1 = Punch-In Outside  
               2 = Punch-Out Outside  
               3 = Both Outside  
            */  
            AND  
            (  
                @PunchType = 0  
  
                OR  
                (  
                    @PunchType = 1  
                    AND AttendanceDeviation.PunchInStatus = 2  
                )  
  
                OR  
                (  
                    @PunchType = 2  
                    AND AttendanceDeviation.PunchOutStatus = 2  
                )  
  
                OR  
                (  
                    @PunchType = 3  
                    AND AttendanceDeviation.PunchInStatus = 2  
                    AND AttendanceDeviation.PunchOutStatus = 2  
                )  
            )  
  
        ORDER BY  
            CASE  
                WHEN @SortBy = 'EmployeeName'  
                 AND @SortOrder = 'ASC'  
                THEN AttendanceDeviation.EmployeeName  
            END ASC,  
  
            CASE  
                WHEN @SortBy = 'EmployeeName'  
                 AND @SortOrder = 'DESC'  
                THEN AttendanceDeviation.EmployeeName  
            END DESC,  
  
            CASE  
                WHEN @SortBy = 'PunchInDateTime'  
                 AND @SortOrder = 'ASC'  
                THEN AttendanceDeviation.PunchInDateTime  
            END ASC,  
  
            CASE  
                WHEN @SortBy = 'PunchInDateTime'  
                 AND @SortOrder = 'DESC'  
                THEN AttendanceDeviation.PunchInDateTime  
            END DESC,  
  
            CASE  
                WHEN @SortBy = 'PunchInDistanceMeters'  
                 AND @SortOrder = 'ASC'  
                THEN AttendanceDeviation.PunchInDistanceMeters  
            END ASC,  
  
            CASE  
                WHEN @SortBy = 'PunchInDistanceMeters'  
                 AND @SortOrder = 'DESC'  
                THEN AttendanceDeviation.PunchInDistanceMeters  
            END DESC,  
  
            AttendanceDeviation.AttendanceId DESC  
  
        OFFSET (@PageIndex - 1) * @PageSize ROWS  
        FETCH NEXT @PageSize ROWS ONLY;  
  
    END TRY  
    BEGIN CATCH  
  
        DECLARE  
            @ObjectName VARCHAR(500),  
            @ErrorMsg NVARCHAR(4000);  
  
        SET @ObjectName = OBJECT_NAME(@@PROCID);  
        SET @ErrorMsg = ERROR_MESSAGE();  
  
        EXEC dbo.SaveDBErrorLog  
            @ObjectName = @ObjectName,  
            @ErrorMsg = @ErrorMsg;  
  
    END CATCH  
END;