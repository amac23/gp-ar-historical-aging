CREATE PROCEDURE [dbo].[PROC_AR_HIST]
AS
BEGIN
	SET NOCOUNT ON;

	TRUNCATE TABLE ar_hist

	DECLARE @agingdate VARCHAR(10)
	DECLARE @INPUTDATE VARCHAR(10)
	DECLARE @loopcount INT

	--start with the 1st day of the month 12 months ago
	SET @loopcount = - (datediff(d, convert(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 12, 0), 20), getdate()))
	SET @agingdate = convert(VARCHAR(10), dateadd(d, @loopcount, getdate()), 20)

	--loop through and insert a snapshot of each day until today
	WHILE @loopcount <= 0
	BEGIN
		SET @INPUTDATE = @agingdate

		INSERT INTO ar_hist
		SELECT [Child Customer ID]
			,[Child Customer Name]
			,[Parent Customer ID]
			,[Parent Customer Name]
			,[Statement Name]
			,[Country Code]
			,[Country]
			,[Salesperson ID]
			,[Doc Type]
			,[Doc Number]
			,[Doc Date]
			,[GL Post Date]
			,[Due Date]
			,[Days Open]
			,[Days Past Due]
			,[Void Date]
			,[Date Invoice Paid Off]
			,[PO Number]
			,[Payment Terms]
			,[Currency]
			,[Outstanding Amount USD]
			,[Original Trx Amount USD]
			,[Outstanding Amount Foreign Currency]
			,[Original Trx Amount Foreign Currency]
			,[Revalued Outstanding Amount USD]
			,[Hist Exchange Date]
			,[Hist Exchange Rate]
			,[Curr Exchange Rate]
			,[Aging Bucket]
			,[Document Status]
			,[Aging Date]
			,CONCAT (
				[Parent Customer ID]
				,[Child Customer ID]
				,[Statement Name]
				) [CustomerKey]
			,CONCAT (
				[Doc Type]
				,[Doc Number]
				) [DocumentKey]
		FROM (
			SELECT cc.CUSTNMBR [Child Customer ID]
				,cc.CUSTNAME [Child Customer Name]
				,CASE cc.CPRCSTNM
					WHEN ''
						THEN a.CUSTNMBR
					ELSE cc.CPRCSTNM
					END [Parent Customer ID]
				,CASE cc.CPRCSTNM
					WHEN ''
						THEN cc.CUSTNAME
					ELSE pc.CUSTNAME
					END [Parent Customer Name]
				,cc.STMTNAME [Statement Name]
				,cc.CCode [Country Code]
				,cc.COUNTRY [Country]
				,cc.SLPRSNID [Salesperson ID]
				,a.RMDTYPAL [Doc Type]
				,a.DOCNUMBR [Doc Number]
				,a.DOCDATE [Doc Date]
				,a.GLPOSTDT [GL Post Date]
				,a.DUEDATE [Due Date]
				,CASE 
					WHEN a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0) <> 0
						THEN DATEDIFF(d, a.DOCDATE, @INPUTDATE)
					ELSE datediff(d, a.DOCDATE, a.DINVPDOF)
					END [Days Open]
				,CASE 
					WHEN a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0) = 0
						THEN datediff(d, a.duedate, a.DINVPDOF)
					ELSE datediff(d, a.duedate, @INPUTDATE)
					END [Days Past Due]
				,a.VOIDDATE [Void Date]
				,a.DINVPDOF [Date Invoice Paid Off]
				,a.CSPORNBR [PO Number]
				,a.PYMTRMID [Payment Terms]
				,a.CURNCYID [Currency]
				,CASE 
					WHEN a.RMDTYPAL > 6
						THEN (- (a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)))
					ELSE a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)
					END [Outstanding Amount USD]
				,CASE 
					WHEN a.RMDTYPAL > 6
						THEN - a.ORTRXAMT
					ELSE a.ORTRXAMT
					END [Original Trx Amount USD]
				,CASE 
					WHEN mc.ORORGTRX IS NULL
						THEN CASE 
								WHEN a.RMDTYPAL > 6
									THEN (- (a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)))
								ELSE a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)
								END
					ELSE round(CASE 
									WHEN a.RMDTYPAL > 6
										THEN (- (a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)))
									ELSE a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)
									END / mc.XCHGRATE, 2)
					END [Outstanding Amount Foreign Currency]
				,coalesce(CASE 
						WHEN a.RMDTYPAL > 6
							THEN mc.ORORGTRX * - 1
						ELSE mc.ORORGTRX
						END, CASE 
						WHEN a.RMDTYPAL > 6
							THEN - a.ORTRXAMT
						ELSE a.ORTRXAMT
						END) [Original Trx Amount Foreign Currency]
				,CASE 
					WHEN mc.ORORGTRX IS NULL
						THEN CASE 
								WHEN a.RMDTYPAL > 6
									THEN (- (a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)))
								ELSE a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)
								END
					ELSE round(CASE 
									WHEN a.RMDTYPAL > 6
										THEN (- (a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)))
									ELSE a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)
									END / mc.XCHGRATE * e.XCHGRATE, 2)
					END [Revalued Outstanding Amount USD]
				,mc.EXCHDATE [Hist Exchange Date]
				,mc.XCHGRATE [Hist Exchange Rate]
				,e.XCHGRATE [Curr Exchange Rate]
				,CASE 
					WHEN datediff(d, a.duedate, @INPUTDATE) < 1
						THEN '1. Current'
					WHEN datediff(d, a.duedate, @INPUTDATE) BETWEEN 1 AND 30
						THEN '2. 1-30 Days'
					WHEN datediff(d, a.DUEDATE, @INPUTDATE) BETWEEN 31 AND 60
						THEN '3. 31-60 Days'
					WHEN datediff(d, a.DUEDATE, @INPUTDATE) BETWEEN 61 AND 90
						THEN '4. 61-90 Days'
					WHEN datediff(d, a.DUEDATE, @INPUTDATE) BETWEEN 91 AND 120
						THEN '5. 91-120 Days'
					WHEN datediff(d, a.DUEDATE, @INPUTDATE) BETWEEN 121 AND 150
						THEN '6. 121-150 Days'
					WHEN datediff(d, a.DUEDATE, @INPUTDATE) > 150
						THEN '7. 151 and Over'
					END [Aging Bucket]
				,CASE 
					WHEN CASE 
							WHEN a.RMDTYPAL > 6
								THEN (- (a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)))
							ELSE a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0)
							END <> 0
						THEN 'Open'
					ELSE 'Closed'
					END [Document Status]
				,@INPUTDATE AS [Aging Date]
			FROM (
				SELECT CUSTNMBR
					,RMDTYPAL
					,DOCDATE
					,GLPOSTDT
					,CASE RMDTYPAL
						WHEN 9
							THEN GLPOSTDT
						ELSE DUEDATE
						END DUEDATE
					,DOCNUMBR
					,VOIDDATE
					,DINVPDOF
					,CURTRXAM
					,CASE RMDTYPAL
						WHEN 8
							THEN ORTRXAMT - CASHAMNT
						ELSE ORTRXAMT
						END ORTRXAMT
					,CSPORNBR
					,CURNCYID
					,PYMTRMID
				FROM dbo.RM20101 -- Open Transactions
				WHERE GLPOSTDT <= @INPUTDATE
					AND (
						VOIDDATE = '1/1/1900'
						OR VOIDDATE > @INPUTDATE
						)
					AND RMDTYPAL <> 6
				
				UNION
				
				SELECT CUSTNMBR
					,RMDTYPAL
					,DOCDATE
					,GLPOSTDT
					,CASE RMDTYPAL
						WHEN 9
							THEN GLPOSTDT
						ELSE DUEDATE
						END DUEDATE
					,DOCNUMBR
					,VOIDDATE
					,DINVPDOF
					,CURTRXAM
					,CASE RMDTYPAL
						WHEN 8
							THEN ORTRXAMT - CASHAMNT
						ELSE ORTRXAMT
						END ORTRXAMT
					,CSPORNBR
					,CURNCYID
					,PYMTRMID
				FROM dbo.RM30101 -- Historical Transactions
				WHERE GLPOSTDT <= @INPUTDATE
					AND (
						VOIDDATE = '1/1/1900'
						OR VOIDDATE > @INPUTDATE
						)
					AND RMDTYPAL <> 6
				) a
			LEFT JOIN (
				SELECT sum(ap.APPTOAMT) + sum(ap.WROFAMNT) + sum(ap.DISTKNAM) amount
					,APTODCNM
					,APTODCTY
				FROM (
					SELECT ApplyFromGLPostDate
						,GLPOSTDT
						,APTODCNM
						,APTODCTY
						,APPTOAMT
						,WROFAMNT
						,DISTKNAM
						,APFRDCNM
						,APFRDCTY
					FROM dbo.RM20201 -- Open Transactions Apply
					WHERE POSTED = 1
						AND APTODCTY <> 6
					
					UNION
					
					SELECT ApplyFromGLPostDate
						,GLPOSTDT
						,APTODCNM
						,APTODCTY
						,APPTOAMT
						,WROFAMNT
						,DISTKNAM
						,APFRDCNM
						,APFRDCTY
					FROM dbo.RM30201 -- Historical Transasctions Apply
					WHERE APTODCTY <> 6
					) ap --apply
				WHERE ap.GLPOSTDT <= @INPUTDATE
					AND ApplyFromGLPostDate <= @INPUTDATE
				GROUP BY APTODCNM
					,APTODCTY
				) b ON b.APTODCNM = a.DOCNUMBR
				AND b.APTODCTY = a.RMDTYPAL
			LEFT JOIN (
				SELECT sum(ap.APFRMAPLYAMT) amount
					,APFRDCNM
					,APFRDCTY
				FROM (
					SELECT ApplyToGLPostDate
						,GLPOSTDT
						,APFRDCNM
						,APFRDCTY
						,APFRMAPLYAMT
						,APTODCNM
						,APTODCTY
					FROM dbo.RM20201 -- Open Transactions Apply
					WHERE POSTED = 1
						AND APTODCTY <> 6
					
					UNION
					
					SELECT ApplyToGLPostDate
						,GLPOSTDT
						,APFRDCNM
						,APFRDCTY
						,APFRMAPLYAMT
						,APTODCNM
						,APTODCTY
					FROM dbo.RM30201 -- Historical Transactions Apply
					WHERE APTODCTY <> 6
					) ap --apply
				WHERE ap.GLPOSTDT <= @INPUTDATE
					AND ApplyToGLPostDate <= @INPUTDATE
				GROUP BY APFRDCNM
					,APFRDCTY
				) c ON c.APFRDCNM = a.DOCNUMBR
				AND c.APFRDCTY = a.RMDTYPAL
			LEFT JOIN dbo.RM00101 cc -- customer master
				ON a.CUSTNMBR = cc.CUSTNMBR
			LEFT JOIN dbo.RM00101 pc -- parent customer master
				ON cc.CPRCSTNM = pc.CUSTNMBR
			LEFT JOIN dbo.MC020102 mc -- FX table
				ON a.RMDTYPAL = mc.RMDTYPAL
				AND a.DOCNUMBR = mc.DOCNUMBR
			LEFT JOIN (
				SELECT g.EXGTBLID
					,g.EXCHDATE
					,XCHGRATE
				FROM (
					SELECT min(c.time1) Time1
						,EXGTBLID
						,c.EXCHDATE
					FROM Dynamics.dbo.MC00100 C -- Master FX table
					WHERE c.EXCHDATE = @INPUTDATE
					GROUP BY EXGTBLID
						,c.EXCHDATE
					) g
				LEFT JOIN Dynamics.dbo.MC00100 f ON (
						g.Time1 = f.time1
						AND g.exgtblid = f.exgtblid
						AND g.EXCHDATE = f.EXCHDATE
						)
				) e ON e.EXGTBLID = mc.EXGTBLID
			WHERE a.ORTRXAMT - coalesce(b.amount, 0) - coalesce(c.amount, 0) <> 0
			) a

		SET @loopcount += 1
		SET @agingdate = convert(VARCHAR(10), dateadd(d, @loopcount, getdate()), 20)
	END
END
GO
