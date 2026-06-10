"""Generate 2000+ realistic Indian transaction training data."""
import csv, random
from pathlib import Path

random.seed(42)
BASE = Path(__file__).parent

BANKS = ["HDFC", "SBI", "ICICI", "Axis", "Kotak", "PNB", "BOB", "Canara", "IndusInd", "Yes Bank"]
ACCT_SUFFIXES = [f"**{random.randint(1000,9999)}" for _ in range(20)]
UPI_SUFFIXES = ["@ybl", "@paytm", "@axl", "@icici", "@hdfcbank", "@okaxis", "@okhdfcbank", "@axisbank", "@sbi", "@kotak"]

CATEGORIES = {
    "food_delivery": {
        "merchants": ["Swiggy", "Zomato", "EatFit", "Box8", "FreshMenu", "Dominos", "Pizza Hut", "McDonalds", "KFC", "Burger King", "Behrouz", "Faasos", "Chaayos", "Dunzo Daily", "Zepto Cafe", "Subway", "Taco Bell", "Wow Momo", "Biryani Blues", "Paradise Biryani", "Haldirams", "Barbeque Nation", "Rebels", "Mojo Pizza", "Oven Story", "La Pinos", "Chicago Pizza", "Wendy's", "Theobroma", "Mad Over Donuts"],
        "amount_range": (80, 1500),
    },
    "groceries": {
        "merchants": ["DMart", "BigBasket", "Blinkit", "Zepto", "JioMart", "Reliance Fresh", "More Supermarket", "Star Bazaar", "Natures Basket", "Spencers", "Grofers", "Country Delight", "Milk Basket", "Licious", "FreshToHome", "BB Daily", "Flipkart Grocery", "Amazon Fresh", "Swiggy Instamart", "Dunzo", "Metro Cash", "Vishal Mega Mart", "Easy Day", "Heritage Fresh", "Ratnadeep", "Spar Hypermarket"],
        "amount_range": (100, 5000),
    },
    "transport_ride": {
        "merchants": ["Uber", "Ola", "Rapido", "BluSmart", "Meru", "InDrive", "Auto Rickshaw", "Uber Auto", "Ola Auto", "Rapido Bike", "Namma Yatri", "Uber Moto", "Porter", "Dunzo", "WheelsEye"],
        "amount_range": (50, 2500),
    },
    "transport_fuel": {
        "merchants": ["HP Petrol Pump", "Indian Oil", "BPCL", "Shell", "Bharat Petroleum", "Reliance Petrol", "IOCL", "HP Gas", "Indane Gas", "Total Energies", "Nayara Energy", "Essar Petrol"],
        "amount_range": (200, 5000),
    },
    "shopping_online": {
        "merchants": ["Amazon.in", "Flipkart", "Myntra", "Ajio", "Nykaa", "Meesho", "Tata CLiQ", "Snapdeal", "FirstCry", "Purplle", "Lenskart", "Bewakoof", "Urbanic", "Croma", "Reliance Digital", "Pepperfry", "Urban Ladder", "Boat Lifestyle", "Noise", "Sugar Cosmetics", "Mamaearth", "WOW Skin", "boAt", "Chumbak"],
        "amount_range": (200, 15000),
    },
    "shopping_offline": {
        "merchants": ["Lifestyle", "Central", "Shoppers Stop", "Westside", "Reliance Trends", "Max Fashion", "Pantaloons", "Decathlon", "H&M", "Zara", "Marks Spencer", "FabIndia", "Bata", "Metro Shoes", "Titan Eye Plus", "Tanishq", "Kalyan Jewellers", "Manyavar", "Raymond", "Allen Solly", "Van Heusen", "Peter England"],
        "amount_range": (300, 20000),
    },
    "bills_telecom": {
        "merchants": ["Jio", "Airtel", "Vi Vodafone", "BSNL", "ACT Fibernet", "Hathway", "Tata Play", "DishTV", "D2H", "Airtel Xstream", "Jio Fiber", "Spectra", "Tikona", "MTNL", "Excitel"],
        "amount_range": (149, 2000),
    },
    "bills_electricity": {
        "merchants": ["TATA Power", "BESCOM", "MSEDCL", "CESC", "Torrent Power", "Adani Electricity", "BSES Rajdhani", "BSES Yamuna", "KSEB", "TANGEDCO", "UHBVN", "PSPCL", "WBSEDCL", "CSPDCL"],
        "amount_range": (500, 8000),
    },
    "bills_water": {
        "merchants": ["Delhi Jal Board", "BWSSB", "MCGM Water", "Municipal Water", "Chennai Metro Water", "HMWSSB", "Pune Municipal Water", "PCMC Water", "Jaipur Water", "Lucknow Jal Nigam"],
        "amount_range": (100, 2000),
    },
    "entertainment": {
        "merchants": ["Netflix", "Spotify", "Amazon Prime", "Disney+ Hotstar", "SonyLIV", "JioCinema", "PVR", "INOX", "BookMyShow", "Zee5", "Voot", "MX Player", "YouTube Premium", "Apple TV+", "Lionsgate Play", "Cinepolis", "Fun Cinemas", "Carnival Cinemas"],
        "amount_range": (99, 2500),
    },
    "health_medical": {
        "merchants": ["Apollo Pharmacy", "Fortis Hospital", "Max Hospital", "Practo", "PharmEasy", "1mg", "Netmeds", "MedPlus", "Dr Lal PathLabs", "Thyrocare", "Manipal Hospital", "Narayana Health", "AIIMS", "Medanta", "SRL Diagnostics", "Metropolis Lab", "Cipla Health"],
        "amount_range": (100, 25000),
    },
    "health_fitness": {
        "merchants": ["Cult.fit", "Golds Gym", "Anytime Fitness", "HealthifyMe", "Fitness First", "Snap Fitness", "Talwalkars", "The Quad", "F45 Training", "CrossFit", "Yoga House", "Sarva Yoga"],
        "amount_range": (500, 5000),
    },
    "education": {
        "merchants": ["Unacademy", "BYJUS", "Coursera", "Udemy", "upGrad", "Simplilearn", "Khan Academy", "Vedantu", "Physics Wallah", "Allen Career", "Aakash Institute", "Great Learning", "Scaler Academy", "Coding Ninjas", "GeeksforGeeks"],
        "amount_range": (500, 50000),
    },
    "salary": {
        "merchants": ["TCS", "Infosys", "Wipro", "HCL Tech", "Amazon India", "Flipkart", "Google India", "Microsoft India", "Accenture", "Cognizant", "Tech Mahindra", "Reliance Industries", "HDFC Bank", "ICICI Bank", "Bharti Airtel", "Tata Motors", "L&T", "Bajaj Auto"],
        "amount_range": (20000, 300000),
    },
    "freelance": {
        "merchants": ["Upwork", "Fiverr", "Toptal", "Freelancer.com", "99designs", "Guru.com", "PeoplePerHour", "client payment", "project payment", "consulting fee", "design work", "development work", "content writing"],
        "amount_range": (5000, 100000),
    },
    "investment": {
        "merchants": ["Groww", "Zerodha", "Angel One", "Coin by Zerodha", "HDFC MF", "SBI MF", "Kuvera", "ET Money", "Paytm Money", "5Paisa", "Motilal Oswal", "ICICI Direct", "Nippon MF", "Axis MF", "Mirae Asset", "DSP MF"],
        "amount_range": (500, 100000),
    },
    "rent": {
        "merchants": ["House rent", "Flat rent", "PG rent", "Room rent", "Office rent", "Landlord", "Society maintenance", "Rent to owner"],
        "amount_range": (5000, 50000),
    },
    "emi": {
        "merchants": ["HDFC Home Loan", "SBI Home Loan", "Bajaj Finance EMI", "ICICI Personal Loan", "Axis Car Loan", "Kotak EMI", "Tata Capital EMI", "IDFC First EMI", "Mahindra Finance", "Hero FinCorp", "Bajaj Auto Finance", "Samsung Finance"],
        "amount_range": (2000, 50000),
    },
    "subscription": {
        "merchants": ["YouTube Premium", "iCloud", "Google One", "LinkedIn Premium", "Strava", "Apple Music", "Headspace", "Calm", "Notion", "Canva Pro", "Adobe CC", "Microsoft 365", "Dropbox", "ChatGPT Plus", "Grammarly"],
        "amount_range": (79, 2000),
    },
    "travel": {
        "merchants": ["MakeMyTrip", "IRCTC", "Goibibo", "Yatra", "EaseMyTrip", "Cleartrip", "Ixigo", "OYO", "Airbnb", "Treebo", "FabHotels", "RedBus", "AbhiBus", "IndiGo", "SpiceJet", "Air India", "Vistara", "AirAsia"],
        "amount_range": (200, 50000),
    },
    "personal_care": {
        "merchants": ["Urban Company", "Salon", "Nykaa", "Beauty Parlor", "Haircut", "Spa", "Lakme Salon", "Jawed Habib", "Naturals Salon", "YLG Salon", "Enrich Salon", "Bodycraft", "O2 Spa", "Thai Spa", "Kaya Skin", "VLCC"],
        "amount_range": (200, 5000),
    },
    "gifts": {
        "merchants": ["Amazon Gift", "Flipkart Gift", "Birthday gift", "Wedding gift", "Anniversary gift", "Archies", "Ferns N Petals", "IGP", "Gift card", "Diwali gift", "Rakhi gift", "Christmas gift", "Return gift", "Housewarming gift"],
        "amount_range": (200, 10000),
    },
    "other": {
        "merchants": ["ATM Withdrawal", "Cash deposit", "NEFT Transfer", "IMPS Transfer", "Miscellaneous", "Parking", "Toll Plaza", "FASTag", "Courier", "DTDC", "BlueDart", "Delhivery", "Printing", "Xerox", "Laundry", "Dry cleaning"],
        "amount_range": (50, 10000),
    },
}

TEMPLATES = [
    "{bank}: Rs {amt} debited from a/c {acct} for {merchant}",
    "{bank} SMS: INR {amt} debited UPI txn to {merchant_upi}",
    "{bank}: Rs.{amt} paid to {merchant} via UPI Ref {ref}",
    "{bank} Debit: Rs {amt} to {merchant_upi} UPI",
    "UPI: Rs {amt} to {merchant_upi} for purchase",
    "{bank} CC: {merchant} Rs {amt}",
    "CARD {acct} used at {merchant} for Rs.{amt}",
    "{bank}: Rs {amt} debited for {merchant} purchase",
    "Paid Rs {amt} to {merchant} via GPay",
    "PhonePe: Rs {amt} paid to {merchant}",
    "{bank} Alert: INR {amt} spent at {merchant}",
    "Rs {amt}/- debited {merchant} {bank}",
    "{merchant} - Rs.{amt} paid via UPI",
    "Payment of Rs {amt} to {merchant} successful",
    "{bank} UPI: Rs {amt} to {merchant_upi}",
]

SALARY_TEMPLATES = [
    "Salary credited Rs {amt} from {merchant}",
    "{bank}: Rs {amt} credited - Salary from {merchant}",
    "Monthly salary credit INR {amt} {merchant}",
    "{bank} Credit: Rs {amt} NEFT-{merchant}-SALARY",
    "Salary for {month} - Rs {amt} from {merchant}",
]

INVESTMENT_TEMPLATES = [
    "{merchant}: SIP of Rs {amt} debited",
    "{bank}: Rs {amt} debited for {merchant} MF purchase",
    "Investment: Rs {amt} to {merchant} via UPI",
    "{merchant} - Rs {amt} invested in mutual fund",
    "SIP debit Rs {amt} {merchant} folio",
]

EMI_TEMPLATES = [
    "{merchant}: EMI Rs {amt} debited",
    "{bank}: Rs {amt} debited for {merchant} EMI",
    "Loan EMI Rs {amt} paid to {merchant}",
    "Auto debit Rs {amt} {merchant} loan account",
]

RENT_TEMPLATES = [
    "{merchant} payment Rs {amt} for {month}",
    "{bank}: Rs {amt} NEFT to {merchant}",
    "Rent transfer Rs {amt} to landlord",
    "Monthly rent Rs {amt} paid via UPI",
]

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def fmt_amt(amt):
    """Randomly format amount in Indian style."""
    r = random.random()
    if r < 0.3:
        return f"{amt:,.2f}"
    elif r < 0.5:
        return f"{amt:.0f}"
    elif r < 0.7:
        return f"{amt:.0f}/-"
    else:
        return f"{amt:,.0f}"


def gen_row(category):
    info = CATEGORIES[category]
    merchant = random.choice(info["merchants"])
    lo, hi = info["amount_range"]
    amt = round(random.uniform(lo, hi), 2)
    bank = random.choice(BANKS)
    acct = random.choice(ACCT_SUFFIXES)
    upi_handle = merchant.lower().replace(" ", "").replace(".", "")[:12] + random.choice(UPI_SUFFIXES)
    ref = random.randint(100000000, 999999999)
    month = random.choice(MONTHS)

    if category == "salary":
        tmpl = random.choice(SALARY_TEMPLATES)
    elif category == "investment":
        tmpl = random.choice(INVESTMENT_TEMPLATES)
    elif category == "emi":
        tmpl = random.choice(EMI_TEMPLATES)
    elif category == "rent":
        tmpl = random.choice(RENT_TEMPLATES)
    else:
        tmpl = random.choice(TEMPLATES)

    desc = tmpl.format(bank=bank, amt=fmt_amt(amt), acct=acct, merchant=merchant,
                       merchant_upi=upi_handle, ref=ref, month=month)

    # Add variation: occasional typos/abbreviations
    if random.random() < 0.1:
        desc = desc.upper()
    elif random.random() < 0.1:
        desc = desc.lower()
    if random.random() < 0.05:
        desc = desc.replace("Rs", "Rs.")
    if random.random() < 0.05:
        desc = desc.replace("debited", "dbtd")

    return desc, round(amt, 2), category


def main():
    rows = []
    samples_per_cat = 92  # 23 * 92 = 2116
    for cat in CATEGORIES:
        for _ in range(samples_per_cat):
            rows.append(gen_row(cat))

    random.shuffle(rows)

    out = BASE / "training_data.csv"
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["description", "amount", "category"])
        for desc, amt, cat in rows:
            w.writerow([desc, amt, cat])

    print(f"Generated {len(rows)} rows -> {out}")


if __name__ == "__main__":
    main()
