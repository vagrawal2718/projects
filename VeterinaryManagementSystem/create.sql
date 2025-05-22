-- Create Database
DROP DATABASE IF EXISTS VeterinaryClinic;
CREATE DATABASE VeterinaryClinic;
USE VeterinaryClinic;


-- Table: OWNER_CONTACT
CREATE TABLE OWNER_CONTACT (
    Email VARCHAR(100),
    First_Name VARCHAR(50) NOT NULL,
    Middle_Name VARCHAR(50),
    Last_Name VARCHAR(50),
    Phone_Number VARCHAR(10) NOT NULL,
    CHECK (Phone_Number REGEXP '^[0-9]{10}$'), -- Ensures exactly 10 digits
    CHECK (Email REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'), -- Valid email format check
    PRIMARY KEY (Email)
);

CREATE TABLE OWNER (
    Owner_ID INT  UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    City VARCHAR(50) NOT NULL,
    Pin_Code INT UNSIGNED NOT NULL,
    Street_name VARCHAR(50),
    House_no VARCHAR(10),
    Email VARCHAR(100) NOT NULL,
    CHECK (Pin_Code BETWEEN 100000 AND 999999), -- Ensures exactly 6 digits
    
    FOREIGN KEY (Email) REFERENCES OWNER_CONTACT (Email)   ON DELETE CASCADE
        ON UPDATE CASCADE
);
-- Table: ANIMAL
CREATE TABLE ANIMAL (
    Animal_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY ,
    Name VARCHAR(50) NOT NULL,
    Species VARCHAR(50),
    Breed VARCHAR(50),
    Gender CHAR(1) CHECK (Gender IN ('M', 'F')) NOT NULL,
    DOB DATE,
    Weight FLOAT,
    Height FLOAT,
    Owner_ID INT  UNSIGNED,
    FOREIGN KEY (Owner_ID) REFERENCES OWNER (Owner_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    CHECK (DOB <= ('2024-11-26') AND DOB >= ('1980-11-26') ) -- DOB cannot be in the future or more than 50 years ago
);

-- Table: ANIMAL_ALLERGIES
CREATE TABLE ANIMAL_ALLERGIES (
    Animal_ID INT UNSIGNED NOT NULL,
    Allergies VARCHAR(255) NOT NULL,
    PRIMARY KEY (Animal_ID, Allergies),
    FOREIGN KEY (Animal_ID) REFERENCES ANIMAL (Animal_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Table: OWNER

-- Table: SUPPLIER
CREATE TABLE SUPPLIER (
    Supplier_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100),
    Facility_No VARCHAR(20) NOT NULL,
    Street_Name VARCHAR(100),
    City VARCHAR(50),
    Pin_Code INT UNSIGNED NOT NULL,
    CHECK (Pin_Code BETWEEN 100000 AND 999999) -- Ensures exactly 6 digits
);


-- Table: MEDICINE_INVENTORY
CREATE TABLE MEDICINE_INVENTORY (
    Medicine_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    Medicine_Name VARCHAR(100) UNIQUE,
    Type VARCHAR(50) NOT NULL,
    Expiration_Date DATE,
    Current_Stock INT,
    Supplier_ID INT UNSIGNED NOT NULL,
    Quantity INT,

    CHECK (Current_Stock >= 0),                   -- Ensure stock is zero or positive
    CHECK (Quantity > 0),                         -- Ensure quantity is greater than 0
    FOREIGN KEY (Supplier_ID) REFERENCES SUPPLIER (Supplier_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    CHECK (Type IN ('Vaccine', 'Antibiotic', 'Painkiller', 'Vitamin', 'Sedative', 'Anti-Inflammatory','Other'))
);


-- Table: MEDICINE_STORAGE
CREATE TABLE MEDICINE_STORAGE (
    Medicine_ID INT  UNSIGNED  NOT NULL,
    Storage_Locations VARCHAR(255) NOT NULL,
    PRIMARY KEY (Medicine_ID, Storage_Locations),
    FOREIGN KEY (Medicine_ID) REFERENCES MEDICINE_INVENTORY (Medicine_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Table: SUPPLIER_CONTACT_INFO
CREATE TABLE SUPPLIER_CONTACT_INFO (
    Supplier_ID INT  UNSIGNED NOT NULL,
    Contact_Info VARCHAR(10) NOT NULL,
    CHECK (Contact_Info REGEXP '^[0-9]{10}$'), -- Ensures exactly 10 digits
    PRIMARY KEY (Supplier_ID, Contact_Info),
    FOREIGN KEY (Supplier_ID) REFERENCES SUPPLIER (Supplier_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Table: VET_CONTACT
CREATE TABLE VET_CONTACT (
    Contact_Info VARCHAR(10),
    CHECK (Contact_Info REGEXP '^[0-9]{10}$'), -- Ensures exactly 10 digits
    First_Name VARCHAR(50) NOT NULL,
    Middle_Name VARCHAR(50),
    Last_Name VARCHAR(50),
    PRIMARY KEY (Contact_Info)
);

-- Table: VETERINARIAN
CREATE TABLE VETERINARIAN (
    Vet_ID INT  UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    Years_of_Experience INT UNSIGNED,
     Specialization ENUM(
        'Surgeon',
        'Dentist',
        'General Practitioner',
        'Dermatologist',
        'Oncologist',
        'Cardiologist',
        'Radiologist',
        'Neurologist',
        'Orthopedic Specialist',
        'Behaviorist',
        'Ophthalmologist',
        'Nutritionist'
    ) NOT NULL,
    Contact_Info VARCHAR(10),
    Super_Vet_ID INT  UNSIGNED ,
    FOREIGN KEY (Super_Vet_ID) REFERENCES VETERINARIAN (Vet_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Contact_Info) REFERENCES VET_CONTACT (Contact_Info)   ON DELETE CASCADE
        ON UPDATE CASCADE
);



-- Table: APPOINTMENT
CREATE TABLE APPOINTMENT (
    Appointment_ID INT  UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    Date_Time DATETIME NOT NULL,
    Appointment_Type VARCHAR(50) NOT NULL,
    Status VARCHAR(50) NOT NULL,
    Vet_ID INT  UNSIGNED  NOT NULL,
    Animal_ID INT  UNSIGNED NOT NULL,
    FOREIGN KEY (Vet_ID) REFERENCES VETERINARIAN (Vet_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Animal_ID) REFERENCES ANIMAL (Animal_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    CHECK (Appointment_Type IN ('Consultation', 'Follow-up', 'Surgery', 'Vaccination', 'Emergency', 'Check-up')),
    CHECK (Status IN ('Scheduled', 'Completed', 'Cancelled', 'In Progress', 'Pending'))
);


-- Table: STAFF_CONTACT
CREATE TABLE STAFF_CONTACT (
    Contact_Info VARCHAR(100),
    CHECK (Contact_Info REGEXP '^[0-9]{10}$'), -- Ensures exactly 10 digits
    First_Name VARCHAR(50) NOT NULL,
    Middle_Name VARCHAR(50),
    Last_Name VARCHAR(50),
    PRIMARY KEY (Contact_Info)
);

-- Table: CLINIC_STAFF
CREATE TABLE CLINIC_STAFF (
    Staff_ID INT  UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    Type VARCHAR(50) NOT NULL,
    Shift VARCHAR(50) NOT NULL,
    Qualification VARCHAR(100),
    Contact_Info VARCHAR(10) NOT NULL,
    FOREIGN KEY (Contact_Info) REFERENCES STAFF_CONTACT (Contact_Info)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    CHECK (Type IN ('Receptionist', 'Lab-Technician', 'Nurse')),
    CHECK (Shift REGEXP '^(M|T|W|Th|F|S|Su) [0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$') -- Validates day and time format F 13:00-21:00, Su 09:00-17:00
);



-- Table: DISEASE
CREATE TABLE DISEASE (
    Disease_ID INT  UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    Disease_Name VARCHAR(100) UNIQUE,
    Disease_Type VARCHAR(50),
    Species_Affected VARCHAR(50),
    Symptoms TEXT,
    Typical_Duration INT UNSIGNED,
    Contagious BOOLEAN,
    Zoonotic BOOLEAN,
    CHECK (Typical_Duration > 0), 
    CHECK (Disease_Type IN ('Viral', 'Bacterial', 'Fungal', 'Parasitic', 'Genetic', 'Other'))
);

-- Table: TREATMENT_1
CREATE TABLE TREATMENT_1 (
    Treatment_Type VARCHAR(50) NOT NULL,
    Dosage VARCHAR(50),
    Duration INT UNSIGNED,
    CHECK (Duration > 0), 
    Animal_ID INT  UNSIGNED NOT NULL,
    Disease_ID INT  UNSIGNED  NOT NULL,
    Vet_ID INT  UNSIGNED  NOT NULL,
    FollowUpNeeded BOOLEAN,
    DateAdministered DATE,
    PRIMARY KEY (Animal_ID, Disease_ID, Treatment_Type, Vet_ID),
    FOREIGN KEY (Animal_ID) REFERENCES ANIMAL (Animal_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Disease_ID) REFERENCES DISEASE (Disease_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Vet_ID) REFERENCES VETERINARIAN (Vet_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    CHECK (Dosage REGEXP '^[0-9]+(\\.[0-9]+)?(mg|g|ml)$'), -- Validates dosage format
    CHECK (Treatment_Type IN ('Medication', 'Surgery', 'Therapy', 'Vaccination', 'Physical Therapy', 'Dietary Plan', 'Emergency Care')),
     UNIQUE KEY (Treatment_Type)
);

-- Table: TREATMENT_2
CREATE TABLE TREATMENT_2 (
    Medication_ID INT UNSIGNED NOT NULL,
    Treatment_Type VARCHAR(50) NOT NULL,
    Animal_ID INT  UNSIGNED  NOT NULL,
    Disease_ID INT  UNSIGNED NOT NULL,
    Side_Effects TEXT,
    PRIMARY KEY (Medication_ID, Treatment_Type, Animal_ID, Disease_ID),
    FOREIGN KEY (Medication_ID) REFERENCES MEDICINE_INVENTORY (Medicine_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Animal_ID) REFERENCES ANIMAL (Animal_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Treatment_Type) REFERENCES TREATMENT_1 (Treatment_Type)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Disease_ID) REFERENCES DISEASE (Disease_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Table: BILLING
CREATE TABLE BILLING (
    Date_of_Payment DATE NOT NULL,
    Amount_Paid DECIMAL(10,2),
    CHECK (Amount_Paid > 0),
    Appointment_ID INT UNSIGNED NOT NULL,
    Owner_ID INT  UNSIGNED NOT NULL,
    PRIMARY KEY (Appointment_ID, Date_of_Payment, Owner_ID),
    FOREIGN KEY (Appointment_ID) REFERENCES APPOINTMENT (Appointment_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Owner_ID) REFERENCES OWNER (Owner_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
	UNIQUE KEY (Date_of_Payment)
);

-- Table: PAYMENT_RECORD
CREATE TABLE PAYMENT_RECORD (
    Owner_ID INT  UNSIGNED NOT NULL,
    Appointment_ID INT UNSIGNED NOT NULL,
    Date_of_Payment DATE,
    Treatment_Type VARCHAR(50) NOT NULL,
    Medication_ID INT  UNSIGNED NOT NULL,
    Disease_ID INT  UNSIGNED NOT NULL,
    Vet_ID INT  UNSIGNED NOT NULL,
    Animal_ID INT  UNSIGNED NOT NULL,
    PRIMARY KEY (Owner_ID, Appointment_ID, Date_of_Payment, Treatment_Type, Medication_ID, Disease_ID, Vet_ID, Animal_ID),
    FOREIGN KEY (Owner_ID) REFERENCES OWNER (Owner_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Appointment_ID) REFERENCES APPOINTMENT (Appointment_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Medication_ID) REFERENCES MEDICINE_INVENTORY (Medicine_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Disease_ID) REFERENCES DISEASE (Disease_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Vet_ID) REFERENCES VETERINARIAN (Vet_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Animal_ID) REFERENCES ANIMAL (Animal_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Date_of_Payment) REFERENCES BILLING (Date_of_Payment)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Treatment_Type) REFERENCES TREATMENT_1 (Treatment_Type)   ON DELETE CASCADE
        ON UPDATE CASCADE

);

-- Table: ADMINISTERS_TREATMENT
CREATE TABLE ADMINISTERS_TREATMENT (
    Treatment_Type VARCHAR(50) NOT NULL,
    Medicine_ID INT  UNSIGNED NOT NULL,
    Animal_ID INT  UNSIGNED NOT NULL,
    Disease_ID INT  UNSIGNED NOT NULL,
    Vet_ID INT  UNSIGNED NOT NULL,
    Staff_ID INT  UNSIGNED NOT NULL,
    Owner_ID INT  UNSIGNED NOT NULL,
    PRIMARY KEY (Treatment_Type, Medicine_ID, Animal_ID, Disease_ID, Vet_ID, Staff_ID, Owner_ID),
    FOREIGN KEY (Medicine_ID) REFERENCES MEDICINE_INVENTORY (Medicine_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Animal_ID) REFERENCES ANIMAL (Animal_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Disease_ID) REFERENCES DISEASE (Disease_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Vet_ID) REFERENCES VETERINARIAN (Vet_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Staff_ID) REFERENCES CLINIC_STAFF (Staff_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Owner_ID) REFERENCES OWNER (Owner_ID)   ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (Treatment_Type) REFERENCES TREATMENT_1 (Treatment_Type)   ON DELETE CASCADE
        ON UPDATE CASCADE
);
