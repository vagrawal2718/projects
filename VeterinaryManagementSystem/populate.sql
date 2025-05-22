-- Table: OWNER_CONTACT
INSERT INTO OWNER_CONTACT (Email, First_Name, Middle_Name, Last_Name, Phone_Number)
VALUES
('john.doe@example.com', 'John', NULL, 'Doe', '9876543210'),
('emma.watson@example.com', 'Emma', 'Charlotte', 'Watson', '9876543211'),
('robert.brown@example.com', 'Robert', NULL, 'Brown', '9876543212'),
('alice.smith@example.com', 'Alice', NULL, 'Smith', '9876543213'),
('james.jones@example.com', 'James', 'Arthur', 'Jones', '9876543214');

-- Table: OWNER
INSERT INTO OWNER (City, Pin_Code, Street_name, House_no, Email)
VALUES
('New York', 100011, 'Broadway', '21A', 'john.doe@example.com'),
('San Francisco', 941022, 'Market Street', '15B', 'emma.watson@example.com'),
('Los Angeles', 900011, 'Sunset Blvd', '12', 'robert.brown@example.com'),
('Chicago', 606166, 'Michigan Ave', '10C', 'alice.smith@example.com'),
('Miami', 331011, 'Ocean Drive', '5D', 'james.jones@example.com');

-- Table: ANIMAL
INSERT INTO ANIMAL (Name, Species, Breed, Gender, DOB, Weight, Height, Owner_ID)
VALUES
('Buddy', 'Dog', 'Golden Retriever', 'M', '2018-06-15', 30.5, 60, 1),
('Max', 'Cat', 'Siamese', 'M', '2019-08-10', 5.5, 30, 2),
('Bella', 'Dog', 'Beagle', 'F', '2020-05-01', 12.3, 40, 3),
('Luna', 'Dog', 'Poodle', 'F', '2017-12-11', 25.0, 50, 4),
('Charlie', 'Cat', 'Persian', 'M', '2021-03-17', 6.0, 35, 5);

-- Table: ANIMAL_ALLERGIES
INSERT INTO ANIMAL_ALLERGIES (Animal_ID, Allergies)
VALUES
(1, 'Grass Pollen'),
(2, 'Dust'),
(3, 'Chicken Protein'),
(4, 'Peanuts'),
(5, 'Wheat');


-- Table: SUPPLIER
INSERT INTO SUPPLIER (Name, Facility_No, Street_Name, City, Pin_Code)
VALUES
('VetPharma Co.', 'Unit 12', 'Medical Park', 'Los Angeles', 900011),
('AnimalCare Ltd.', 'Unit 3', 'Veterinary Lane', 'San Diego', 921011),
('PharmaVet Supplies', 'Unit 9', 'Park Avenue', 'New York', 100011),
('PetMed Co.', 'Unit 5', 'Main St', 'San Francisco', 941022),
('HealthyPets Ltd.', 'Unit 4', 'Sunset Blvd', 'Los Angeles', 900102);

-- Table: SUPPLIER_CONTACT_INFO
INSERT INTO SUPPLIER_CONTACT_INFO (Supplier_ID, Contact_Info)
VALUES
(1, '9876543210'),
(2, '2345678901'),
(3, '3456789012'),
(4, '4567890123'),
(5, '5678901234');

-- Table: MEDICINE_INVENTORY
INSERT INTO MEDICINE_INVENTORY (Medicine_Name, Type, Expiration_Date, Current_Stock, Supplier_ID, Quantity)
VALUES
('Canine Parvo Vaccine', 'Vaccine', '2025-06-30', 100, 1, 20),
('Feline Antibiotic', 'Antibiotic', '2024-12-15', 50, 2, 10),
('Pain Relief Tablets', 'Painkiller', '2025-01-20', 200, 1, 50),
('Calcium Supplements', 'Vitamin', '2024-09-10', 150, 3, 30),
('Sedative Injection', 'Sedative', '2025-05-05', 75, 4, 15);

-- Table: MEDICINE_STORAGE
INSERT INTO MEDICINE_STORAGE (Medicine_ID, Storage_Locations)
VALUES
(1, 'Refrigerated Storage'),
(2, 'Main Storage Room'),
(3, 'Secondary Storage'),
(4, 'Cool Dry Storage'),
(5, 'Refrigerated Storage');

-- Table: VET_CONTACT
INSERT INTO VET_CONTACT (Contact_Info, First_Name, Middle_Name, Last_Name)
VALUES
('1234567890', 'Sarah', 'Jane', 'Connor'),
('2345678901', 'Mark', NULL, 'Smith'),
('3456789012', 'Alice', 'Marie', 'Taylor'),
('4567890123', 'David', 'John', 'Williams'),
('5678901234', 'Sophia', NULL, 'Martinez');


-- Table: VETERINARIAN
INSERT INTO VETERINARIAN (Years_of_Experience, Specialization, Contact_Info, Super_Vet_ID)
VALUES
(15, 'General Practitioner', '1234567890', NULL),
(12, 'Surgeon', '5678901234', NULL),
(8, 'Orthopedic Specialist', '2345678901', 1),
(5, 'Dermatologist', '3456789012', 1),
(10, 'Dentist', '4567890123', 2);




-- Table: APPOINTMENT
INSERT INTO APPOINTMENT (Date_Time, Appointment_Type, Status, Vet_ID, Animal_ID)
VALUES
('2024-12-01 10:00:00', 'Consultation', 'Completed', 1, 1),
('2024-12-05 15:30:00', 'Surgery', 'Pending', 2, 2),
('2024-12-10 14:00:00', 'Vaccination', 'Completed', 3, 3),
('2024-12-15 09:00:00', 'Check-up', 'Completed', 4, 4),
('2024-12-20 16:00:00', 'Emergency', 'Completed', 5, 5);

-- Table: STAFF_CONTACT
INSERT INTO STAFF_CONTACT (Contact_Info, First_Name, Middle_Name, Last_Name)
VALUES
('9876543210', 'Lily', 'Anne', 'Johnson'),
('2345678901', 'Henry', NULL, 'Adams'),
('3456789012', 'Sophia', NULL, 'Brown'),
('4567890123', 'James', 'Arthur', 'Green'),
('5678901234', 'Oliver', 'Lucas', 'Scott');

-- Table: CLINIC_STAFF
INSERT INTO CLINIC_STAFF (Type, Shift, Qualification,Contact_Info)
VALUES
('Receptionist', 'M 09:00-17:00', 'High School Diploma','2345678901'),
('Lab-Technician', 'T 08:00-16:00', 'BSc in Biology','9876543210'),
('Nurse', 'W 10:00-18:00', 'Registered Nurse','5678901234'),
('Receptionist', 'Th 09:00-17:00', 'High School Diploma','3456789012'),
('Nurse', 'F 13:00-21:00', 'Certified Nursing Assistant','4567890123');


-- Table: DISEASE
INSERT INTO DISEASE (Disease_Name, Disease_Type, Species_Affected, Symptoms, Typical_Duration, Contagious, Zoonotic)
VALUES
('Canine Distemper', 'Viral', 'Dog', 'Fever, Cough, Nasal Discharge', 14, TRUE, FALSE),
('Feline Herpes', 'Viral', 'Cat', 'Sneezing, Runny Nose', 7, TRUE, FALSE),
('Parvovirus', 'Viral', 'Dog', 'Vomiting, Diarrhea, Lethargy', 21, TRUE, FALSE),
('Rabies', 'Viral', 'Dog', 'Fever, Drooling, Aggression', 7, TRUE, TRUE),
('Feline Leukemia', 'Viral', 'Cat', 'Weight Loss, Anemia', 30, TRUE, TRUE);

-- Table: TREATMENT_1
INSERT INTO TREATMENT_1 (Treatment_Type, Dosage, Duration, Animal_ID, Disease_ID, Vet_ID, FollowUpNeeded, DateAdministered)
VALUES
('Vaccination', '1mg', 1, 1, 1, 1, FALSE, '2024-11-15'),
('Dietary Plan', '5mg', 7, 2, 2, 2, TRUE, '2024-11-20'),
('Therapy', '25mg', 5, 3, 3, 3, TRUE, '2024-11-25'),
('Surgery', '20ml', 1, 4, 4, 4, FALSE, '2024-11-30'),
('Emergency Care', '10ml', 1, 5, 5, 5, TRUE, '2024-12-01');

-- Table: TREATMENT_2
INSERT INTO TREATMENT_2 (Medication_ID, Treatment_Type, Animal_ID, Disease_ID, Side_Effects)
VALUES
(1, 'Vaccination', 1, 1, 'Slight Fever'),
(2, 'Dietary Plan', 2, 2, 'Mild diarrhea, Reduced Appetite'),
(3, 'Therapy', 3, 3, 'Drowsiness, Lethargy' ),
(4, 'Surgery', 4, 4, 'None'),
(5, 'Emergency Care', 5, 5, 'None');

-- Table: BILLING
INSERT INTO BILLING (Date_of_Payment, Amount_Paid, Appointment_ID, Owner_ID)
VALUES
('2024-12-02', 150.75, 1, 1),
('2024-12-06', 300.00, 2, 2),
('2024-12-11', 75.50, 3, 3),
('2024-12-12', 120.00, 4, 4),
('2024-12-15', 200.00, 5, 5);


-- Table: PAYMENT_RECORD
INSERT INTO PAYMENT_RECORD (Owner_ID, Appointment_ID, Date_of_Payment, Treatment_Type, Medication_ID, Disease_ID, Vet_ID, Animal_ID)
VALUES
(1, 1, '2024-12-02', 'Vaccination', 1, 1, 1, 1),
(2, 2, '2024-12-06', 'Dietary Plan', 2, 2, 2, 2),
(3, 3, '2024-12-11', 'Therapy', 3, 3, 3, 3),
(4, 4, '2024-12-12', 'Surgery', 4, 4, 4, 4),
(5, 5, '2024-12-15', 'Emergency Care', 5, 5, 5, 5);


-- Table: ADMINISTERS_TREATMENT
INSERT INTO ADMINISTERS_TREATMENT (Treatment_Type, Medicine_ID, Animal_ID, Disease_ID, Vet_ID, Staff_ID, Owner_ID)
VALUES
('Vaccination', 1, 1, 1, 1, 1, 1),
('Dietary Plan', 2, 2, 2, 2, 2, 2),
('Therapy', 3, 3, 3, 3, 3, 3),
('Surgery', 4, 4, 4, 4, 4, 4),
('Emergency Care', 5, 5, 5, 5, 5, 5);


