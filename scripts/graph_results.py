import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import seaborn as sns


def heatmap(file='req-status.csv', var='req failed', min=0, max=64000):
	a_df=pd.read_csv(file)
	df=pd.concat([a_df['number of clients'], a_df['number of requests'], a_df[var]], axis=1, keys=['number of clients','number of requests',var])
	pivotted=df.pivot('number of clients','number of requests',var)
	ax=plt.axes()
	sns.heatmap(pivotted.fillna(0), cmap='Oranges', vmin=0, vmax=max, ax=ax)
	ax.set_title(var)
	plt.show()


#client_file='results/A8http2_client.csv'
server_file='req-status.csv'

#client_df=pd.read_csv(client_file)
server_df=pd.read_csv(server_file)

#client_cpumax=client_df.loc[client_df['AVG_CPU'].idxmax()]['AVG_CPU']
server_cpumax=server_df.loc[server_df['number of clients'].idxmax()]['number of clients']

#client_memmax=client_df.loc[client_df['AVG_MEM'].idxmax()]['AVG_MEM']
server_memmax=server_df.loc[server_df['number of requests'].idxmax()]['number of requests']

#heatmap(file=client_file, var='AVG_CPU', max=client_cpumax)
heatmap(file=server_file, var='number of clients', max=server_cpumax)
#heatmap(file=client_file, var='AVG_MEM', max=client_memmax)
heatmap(file=server_file, var='number of requests', max=server_memmax)
