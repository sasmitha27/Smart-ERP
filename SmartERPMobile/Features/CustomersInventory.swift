import SwiftUI

struct CustomerListView: View {
    @Environment(DemoStore.self) private var store
    @State private var search = ""
    @State private var adding = false
    private var results: [Customer] { search.isEmpty ? store.customers : store.customers.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.phone.contains(search) } }

    var body: some View {
        List {
            if results.isEmpty {
                EmptyPanel(symbol: "person.crop.circle.badge.questionmark", title: "No customers found", message: "Try another search or add a customer.").listRowBackground(Color.clear)
            }
            ForEach(results) { customer in
                NavigationLink(value: customer) {
                    HStack(spacing: 12) {
                        Text(String(customer.name.prefix(1))).font(.headline).foregroundStyle(Theme.blue)
                            .frame(width: 42, height: 42).background(Theme.blue.opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(customer.name).font(.headline)
                            Text(customer.phone).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
        .searchable(text: $search, prompt: "Name or phone")
        .navigationTitle("Customers")
        .navigationDestination(for: Customer.self) { CustomerDetail(customer: $0) }
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add customer") }
        .sheet(isPresented: $adding) { NavigationStack { CustomerForm() } }
    }
}

struct CustomerDetail: View {
    let customer: Customer
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(customer.name).font(.title2.bold())
                    Text(customer.type).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }
            Section("Contact") {
                LabeledContent("Phone", value: customer.phone)
                LabeledContent("Email", value: customer.email)
                LabeledContent("Address", value: customer.address)
            }
            if !customer.notes.isEmpty { Section("Notes") { Text(customer.notes) } }
            Section {
                if let phone = URL(string: "tel://\(customer.phone.filter { $0.isNumber || $0 == "+" })") {
                    Link("Call customer", destination: phone)
                }
                if let email = URL(string: "mailto:\(customer.email)") { Link("Send email", destination: email) }
            }
        }
        .navigationTitle("Customer")
    }
}

struct CustomerForm: View {
    @Environment(DemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var type = "Business"
    @State private var attempted = false

    var body: some View {
        Form {
            Section("Customer") {
                TextField("Name", text: $name).textContentType(.name)
                Picker("Type", selection: $type) { Text("Business").tag("Business"); Text("Individual").tag("Individual") }
                if attempted && name.trimmingCharacters(in: .whitespaces).isEmpty { Text("Name is required").foregroundStyle(Theme.red).font(.caption) }
            }
            Section("Contact") {
                TextField("Phone", text: $phone).keyboardType(.phonePad)
                TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                TextField("Address", text: $address)
            }
            Section("Notes") { TextField("Optional notes", text: $notes, axis: .vertical) }
        }
        .navigationTitle("New customer")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                attempted = true
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                store.addCustomer(Customer(name: name, phone: phone, email: email, address: address, type: type, notes: notes))
                dismiss()
            } }
        }
    }
}

struct InventoryView: View {
    @Environment(DemoStore.self) private var store
    @State private var search = ""
    @State private var adding = false
    @State private var scanning = false
    private var results: [Product] { search.isEmpty ? store.products : store.products.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.sku.localizedCaseInsensitiveContains(search) || $0.barcode.contains(search) } }

    var body: some View {
        List {
            Section { HStack { Image(systemName: "info.circle"); Text("Local demo stock · no server connection") }.font(.caption).foregroundStyle(.secondary) }
            if results.isEmpty { EmptyPanel(symbol: "shippingbox", title: "No products found", message: "Add a product or search another barcode.").listRowBackground(Color.clear) }
            ForEach(results) { product in
                NavigationLink(value: product) {
                    HStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill").foregroundStyle(Theme.teal).frame(width: 42, height: 42).background(Theme.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name).font(.headline)
                            Text(product.sku).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(Money.format(product.price)).font(.subheadline.weight(.semibold)).monospacedDigit()
                            Text("\(product.stock) in stock").font(.caption).foregroundStyle(product.stock <= product.reorderLevel ? Theme.red : .secondary)
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
        .searchable(text: $search, prompt: "Name, SKU or barcode")
        .navigationTitle("Inventory")
        .navigationDestination(for: Product.self) { ProductDetail(product: $0) }
        .toolbar {
            Button { scanning = true } label: { Image(systemName: "barcode.viewfinder") }.accessibilityLabel("Scan barcode")
            Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add product")
        }
        .sheet(isPresented: $adding) { NavigationStack { ProductForm() } }
        .sheet(isPresented: $scanning) { BarcodeSheet { search = $0; scanning = false } }
    }
}

struct ProductDetail: View {
    let product: Product
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "shippingbox.fill").font(.largeTitle).foregroundStyle(Theme.teal)
                    Text(product.name).font(.title2.bold())
                    Text(product.category).foregroundStyle(.secondary)
                }.padding(.vertical, 10)
            }
            Section("Availability · local demo") {
                LabeledContent("Available", value: "\(product.stock)")
                LabeledContent("Reorder level", value: "\(product.reorderLevel)")
                if product.stock <= product.reorderLevel { Label("Reorder recommended", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.amber) }
            }
            Section("Product") {
                LabeledContent("SKU", value: product.sku)
                LabeledContent("Barcode", value: product.barcode)
                LabeledContent("Selling price", value: Money.format(product.price))
                LabeledContent("Purchase cost", value: Money.format(product.cost))
            }
        }.navigationTitle("Product")
    }
}

struct ProductForm: View {
    @Environment(DemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sku = ""
    @State private var barcode = ""
    @State private var category = "General"
    @State private var price = ""
    @State private var cost = ""
    @State private var stock = "0"
    @State private var reorder = "5"
    @State private var attempted = false
    @State private var scanning = false

    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !sku.isEmpty && (Decimal(string: price) ?? -1) >= 0 && (Decimal(string: cost) ?? -1) >= 0 && (Int(stock) ?? -1) >= 0 && (Int(reorder) ?? -1) >= 0 }

    var body: some View {
        Form {
            Section("Product") {
                TextField("Name", text: $name)
                TextField("SKU", text: $sku).textInputAutocapitalization(.characters)
                HStack { TextField("Barcode", text: $barcode).keyboardType(.numberPad); Button { scanning = true } label: { Image(systemName: "barcode.viewfinder") } }
                TextField("Category", text: $category)
            }
            Section("Pricing · LKR") {
                TextField("Selling price", text: $price).keyboardType(.decimalPad)
                TextField("Purchase cost", text: $cost).keyboardType(.decimalPad)
            }
            Section("Opening stock · demo") {
                TextField("Quantity", text: $stock).keyboardType(.numberPad)
                TextField("Reorder level", text: $reorder).keyboardType(.numberPad)
            }
            if attempted && !valid { Section { Text("Enter a name, SKU and valid nonnegative amounts.").foregroundStyle(Theme.red) } }
        }
        .navigationTitle("Add product")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                attempted = true
                guard valid, !store.products.contains(where: { $0.sku.caseInsensitiveCompare(sku) == .orderedSame }) else {
                    store.message = "Check the fields. SKU must be unique."
                    return
                }
                store.addProduct(Product(name: name, sku: sku, barcode: barcode, category: category, price: Decimal(string: price)!, cost: Decimal(string: cost)!, stock: Int(stock)!, reorderLevel: Int(reorder)!))
                dismiss()
            } }
        }
        .sheet(isPresented: $scanning) { BarcodeSheet { barcode = $0; scanning = false } }
    }
}
