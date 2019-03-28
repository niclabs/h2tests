import seaborn as sns
import pandas as pd
import matplotlib.pyplot as plt

cmap = sns.cm.rocket_r
server_file='req-status.csv'
df=pd.read_csv(server_file)

df.drop_duplicates(['cantidad de clientes', 'cantidad total de peticiones'], inplace=True)
pivot = df.pivot(index='cantidad de clientes', columns='cantidad total de peticiones', values='req failed')
ax = sns.heatmap(pivot, annot=True, cmap=cmap, fmt=".1f", cbar_kws={'label': 'peticiones fallidas promedio'})
plt.show()

print (pivot)
