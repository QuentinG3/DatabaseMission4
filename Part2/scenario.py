############
# Scenario #
############
import psycopg2

#Connection to the DB
conn = psycopg2.connect("dbname=AutomatedCafe user=postgres")
cur = conn.cursor()

#Step 1 : Acquire a table

#Get the first free table id
cur.execute("SELECT MIN(EMPLACEMENT.id)"+
			"FROM EMPLACEMENT WHERE EMPLACEMENT.id NOT IN "+
			"(SELECT EMPLACEMENT.id FROM EMPLACEMENT,CLIENT WHERE CLIENT.emplacement=EMPLACEMENT.id);")
free_table = cur.fetchone()[0]

#Check if there is such a free emplacement
if free_table == None:
	raise Error("free table is None")

#Acquire table
cur.execute("SELECT * FROM ACQUIRE_TABLE(%s);", [free_table])
client_id = cur.fetchone()[0]
print("Client acquire a table. Client ID = "+str(client_id))

#Step 2 : Order a sparkling water

#Get the id for the sparkling water
cur.execute("SELECT id FROM DRINK WHERE name='Sparkling Water';")
sparkling_water = cur.fetchone()[0]

#Check if there is such an id
if sparkling_water == None:
	raise Error("sparkling water is None")

#He orders a sparkling water
print("Client order a sparkling water")
cur.execute("SELECT ORDER_DRINK(%s,ARRAY[ARRAY[%s,%s]]);", [client_id, sparkling_water, 1])
conn.commit()


#Step 3 : Look at the bill

#The client look at the bill
print("Client look at the bill")
cur.execute("SELECT * FROM ISSUE_TICKET(%s);", [client_id])
colnames = [desc[0] for desc in cur.description]
print(colnames)
print(cur.fetchall())

#Step 4 : order a sparkling water

#He orders a sparkling water
print("Client order a sparkling water")
cur.execute("SELECT ORDER_DRINK(%s,ARRAY[ARRAY[%s,%s]]);", [client_id, sparkling_water, 1])
conn.commit()

#Step 5 : Pay the bill

#Get the total to pay
cur.execute("SELECT * FROM TOTAL_AMOUNT(%s);",[client_id])
total = cur.fetchone()[0]

#Pay the table
print("Paying the table for a total of "+str(total))
cur.execute("SELECT * FROM PAY_TABLE(%s,%s);",[client_id,total])
conn.commit()

print("The scenario was a success")


