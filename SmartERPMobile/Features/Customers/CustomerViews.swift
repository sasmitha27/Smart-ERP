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
