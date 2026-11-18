CREATE   PROCEDURE zGetOrderRemarksByOrderId (
@OrderId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
	SELECT OC.OrderCommentId
		,OC.STATUS
		,OC.Comments
		,OC.CreatedBy AS CommentUserId
		,OC.CreatedDate
		,OC.Remarks
	--,CommentName 
	--,NewOrderStatusLabelName 
	FROM OrderComments OC WITH (NOLOCK)
	--INNER JOIN AspNetUsers AU WITH (NOLOCK) ON OC.CreatedBy = AU.UserId
	WHERE OC.OrderId = @OrderId
	ORDER BY OC.OrderCommentId DESC
END

GO

