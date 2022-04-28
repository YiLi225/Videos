# -*- coding: utf-8 -*-
"""
Created on Sat Apr 16 13:25:45 2022

@author: Kat Li
"""

import sqlalchemy as sa
import urllib
import pandas as pd

## checking my code before demo
params = urllib.parse.quote_plus("DRIVER={SQL Server Native Client 11.0};"
                                 "SERVER=localhost\SQLEXPRESS;"
                                 "DATABASE=master;"
                                 "Trusted_Connection=yes")

engine = sa.create_engine("mssql+pyodbc:///?odbc_connect={}".format(params))

### Define query
timeSeries_query = '''
    SELECT *
    FROM [Master].[Dbo].[LongData]
    ORDER BY Id_var, Date_var;
'''

df_series = pd.read_sql(timeSeries_query, engine)
df_series




