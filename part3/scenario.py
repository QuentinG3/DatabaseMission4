from QueryBuilder import *

if __name__ == '__main__':
    db = DatabaseInterface("AutomatedCafe","postgres","localhost","azerty")
    db.connect()


    try:

        #Getting the first free table(for the scenario)
        freeTableId = db.getFirstFreeTable()

        #Acquiring the table with the scanned barcode
        token = db.AcquireTable(freeTableId)
        print("Table with bar code {0} acquired by client {1}".format(freeTableId,token))

        #Getting the id of the Sparkling water int the database
        sparklingWaterId = db.getDrinkByName("Sparkling Water")

        #Ordering a Sparling Water
        newDrinkOrder = list()
        newDrinkOrder.append((sparklingWaterId,1))
        orderId = db.OrderDrinks(token,newDrinkOrder)
        print("Sparkling water ordered")

        #Checking the ticket
        listOrders,price = db.IssueTicket(token)
        print("The occurent ticket is : ")
        print(listOrders)
        print("The total amount to pay is : ")
        print(price)

        #Ordering another Sparling Water
        newDrinkOrder = list()
        newDrinkOrder.append((sparklingWaterId,1))
        orderId = db.OrderDrinks(token,newDrinkOrder)
        print("Another Sparkling water ordered")

        #Paying the bill (with 0.5 tip)
        payedAmount = 3.5
        print("Paying the bill")
        db.PayTable(token,payedAmount)
        print("Bill paid with : {0}".format(payedAmount))


    except Exception as e:
        print(e)
