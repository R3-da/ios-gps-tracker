//
//  NewMapView.swift
//  PackageDeliverySwiftUI
//
//  Created by Baris OZGEN on 9.06.2023.
//

import SwiftUI
import _MapKit_SwiftUI
import Combine

struct NewMapView: View {
    @Bindable var vm : MapViewModel
    @State private var cameraProsition: MapCameraPosition = .camera(MapCamera(centerCoordinate: .locU, distance: 3729, heading: 92, pitch: 70))
    
    @State var selectedItem: MKMapItem? = nil
    @Binding var selectedPickupItem: MKMapItem?
    @Binding var selectedDropOffItem: MKMapItem?
    @Binding var selectedDriverItem: MKMapItem?
    
    @Binding var selectedStep : EDeliveryChoiceSteps
    
    @State private var colorMyPin: LinearGradient = LinearGradient(colors: [.orange, .green], startPoint: .top, endPoint: .center)
    
    @Binding var searchText: String
    private let searchTextPublisher = PassthroughSubject<String, Never>()
    
    @Binding var selectedVehicle : EVehicleType?
    
    @State private var userCoordinates: [CLLocationCoordinate2D] = []
    @State private var isTracking: Bool = false // Tracking flag
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer? = nil
    
    // New properties for spinning speed
    @State private var spinningSpeed: Double = 1.0 // degrees per second
    @State private var isSpinning: Bool = false
    @State private var spinTimer: Timer? = nil
    
    // Function to start the timer
    func startTimer() {
        stopTimer() // Stop any existing timer before starting a new one
        elapsedTime = 0 // Reset elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    // Function to stop the timer
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateCameraPosition(focus centerCoordinate: CLLocationCoordinate2D,
                              distance: Double,
                              pitch: Double) {
        withAnimation(.spring()) {
            cameraProsition = .camera(MapCamera(centerCoordinate: centerCoordinate, distance: distance, pitch: pitch))
        }

        // Schedule the print statement to execute 2 seconds after the animation starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            startSpinning()
        }
    }
    
    // Function to start the spinning
    func startSpinning() {
        isSpinning = true
        spinTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            spinCameraPosition(focus: vm.userCoordinate, speed: spinningSpeed)
        }
    }

    // Function to stop the spinning
    func stopSpinning() {
        isSpinning = false
        spinTimer?.invalidate()
        spinTimer = nil
    }

    func spinCameraPosition(focus centerCoordinate: CLLocationCoordinate2D, speed: Double) {
        if let currentCamera = cameraProsition.camera {
            let currentHeading = currentCamera.heading // Get the current heading
            // Increment heading by speed and normalize it to [0, 360)
            let newHeading = fmod(currentHeading + speed, 360)
            
            cameraProsition = .camera(MapCamera(centerCoordinate: centerCoordinate,
                                                distance: currentCamera.distance,
                                                heading: newHeading >= 0 ? newHeading : newHeading + 360, // Ensure heading is positive
                                                pitch: currentCamera.pitch))
        } else {
            print("Warning: cameraProsition.camera is nil")
            cameraProsition = .camera(MapCamera(centerCoordinate: centerCoordinate, distance: 1000, heading: 0, pitch: 0))
        }
    }

    var body: some View {
        Map(position: $cameraProsition,
            interactionModes: .all,
            selection: $selectedItem){
            
            Annotation("", coordinate: vm.userCoordinate) {
                VStack(spacing: 5) {
                    Text("You are here")
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.bottom, 5) // Add some spacing between text and the view
                        .shadow(color: .white, radius: 5, x: 0, y: 0) // First layer of shadow
                        .shadow(color: .white.opacity(0.7), radius: 10, x: 0, y: 0) // Second layer of shadow for a stronger glow

                    pickupView
                }
                .offset(y: -50) // Adjust this offset as needed to position correctly
            }
            
            // show drivers locations
            if selectedStep == .request &&
                selectedPickupItem != nil  && selectedDriverItem == nil {
                ForEach(vm.searchResultsForDrivers, id: \.self){ result in
                    let driver = EVehicleType.allCases.shuffled().first!
                    Annotation(driver.title, coordinate: result.placemark.coordinate) {
                        ZStack {
                            Circle()
                                .fill(driver.iconColor)
                                .shadow(color: .black, radius: 2)
                            Image(systemName: driver.image)
                                .padding (7)
                                .foregroundStyle(.white)
                        }
                        
                    }
                    .annotationTitles(.automatic)
                }
            }
            else if let selectedDriverItem,
                    let selectedVehicle {
                Annotation(selectedVehicle.title, coordinate: selectedDriverItem.placemark.coordinate) {
                    ZStack {
                        Circle()
                            .fill(selectedVehicle.iconColor)
                            .shadow(color: .black, radius: 2)
                        Image(systemName: selectedVehicle.image)
                            .padding (7)
                            .foregroundStyle(.white)
                    }
                    
                }
                .annotationTitles(.automatic)
            }
            // draw route from driver to pick up
            if let route = vm.routeDriverToPickup {
                MapPolyline(route)
                    .stroke(LinearGradient.gradientWalk, style: .strokeWalk)
            }
            // draw route from pick up to drop off
            if let route = vm.routePickupToDropOff {
                MapPolyline(route)
                    .stroke(.orange, lineWidth: 5)
            }
            
            // find my location. Here is demo
            /*
            ForEach(vm.myLocation, id: \.self){ result in
                Annotation(selectedPickupItem == nil ? "You are here" : "Pickup Point", coordinate: result.placemark.coordinate) {
                    pickupView
                        .onAppear{
                            updateCameraPosition(focus: .locU, distance: 992, heading: 70, pitch: 60)
                        }
                }
                .annotationTitles(.automatic)
            }
            */
            
            // find my location. Here is demo
            /*
            ForEach(vm.myLocation, id: \.self){ result in
                Annotation(selectedPickupItem == nil ? "You are here" : "Pickup Point", coordinate: result.placemark.coordinate) {
                    pickupView
                        .onAppear{
                            updateCameraPosition(focus: vm.userCoordinate ?? .locU, distance: 992, heading: 70, pitch: 60)
                        }
                }
                .annotationTitles(.automatic)
            }
            */
            
            // show drop off locations
            if selectedStep == .dropoff || selectedStep == .request {
                // show search result on the map for drop off loc
                if selectedDropOffItem == nil {
                    ForEach(vm.searchResults, id: \.self){ result in
                        
                        Annotation(result.name ?? "drop off", coordinate: result.placemark.coordinate) {
                            dropOffView
                        }
                        .annotationTitles(.automatic)
                    }
                }
                // if drop off item is selected show only it
                else if let selectedDropOffItem {
                    Annotation(selectedDropOffItem.name ?? "drop off", coordinate: selectedDropOffItem.placemark.coordinate) {
                        dropOffView
                    }
                    .annotationTitles(.automatic)
                }
                
            }
            
            // Draw the user path
            if userCoordinates.count > 1 {
                MapPolyline(coordinates: userCoordinates)
                    .stroke(Color.red, lineWidth: 5) // Set stroke color and width
            }
        }
            .onTapGesture {
                stopSpinning() // Stop spinning on tap
            }
            .simultaneousGesture(DragGesture().onChanged { _ in
                stopSpinning() // Stop spinning on drag
            })
            .simultaneousGesture(MagnificationGesture().onChanged { _ in
                stopSpinning() // Stop spinning on zoom
            })
            .mapControls{
                //MapUserLocationButton()
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .mapStyle(.standard(elevation: .automatic))
            .onAppear{
                vm.searchMyLocation()
                vm.searchDriverLocations()
            }
            .onChange(of: vm.userCoordinate.latitude) {
                if isTracking {
                    userCoordinates.append(vm.userCoordinate)
                }
            }
            .onChange(of: vm.userCoordinate.longitude) {
                if isTracking {
                    userCoordinates.append(vm.userCoordinate)
                }
            }
            
            VStack {
                HStack {
                    Button(action: {
                        updateCameraPosition(focus: vm.userCoordinate, distance: 350, pitch: 60)
                    }) {
                        Image(systemName: "location.circle.fill") // Use an appropriate SF Symbol icon
                            .resizable()
                            .frame(width: 40, height: 40) // Adjust the size of the icon
                            .foregroundColor(.blue) // Icon color
                    }
                    
                    // Button to toggle isTracking and start/stop the timer, with icon and timer next to it
                    Button(action: {
                        isTracking.toggle()
                        if isTracking {
                            startTimer()
                        } else {
                            stopTimer()
                        }
                    }) {
                        HStack {
                            Image(systemName: isTracking ? "pause.circle.fill" : "largecircle.fill.circle")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(isTracking ? .gray : .red)
                            
                            // Show the timer next to the pause icon if isTracking is true
                            if isTracking {
                                Text("\(String(format: "%.0f", elapsedTime))s")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
                .padding() // Padding around the HStack
                .background(
                    RoundedRectangle(cornerRadius: 15) // Adjust the corner radius as needed
                        .fill(Color.white) // Set background color to white
                        .shadow(radius: 5) // Add a shadow for a lifted effect
                )
                .padding(.top, 10) // Adjust to place the buttons closer to the top
                
                // TextField("Name", text: vm.userCoordinate)
                
                ZStack {
                        Text(String(describing: vm.userCoordinate))
                            .padding(20) // Adjust the padding inside the box
                            .font(.caption)
                            .background(Color.blue) // Background color
                            .foregroundColor(.white) // Text color
                            .cornerRadius(10) // Rounded corners
                            .shadow(radius: 5) // Shadow for a lifted effect
                            .frame(width: 200, height: 100) // Set width and height
                            .padding() // Padding around the text box
                    }
                
                Spacer() // Pushes everything else below
            }
        
            .onChange(of: selectedItem){
                guard let selectedItem else {return}
                if selectedStep == .pickup {
                    selectedPickupItem = selectedItem
                }
                if selectedStep == .dropoff {
                    selectedDropOffItem = selectedItem
                }
                if selectedStep == .dropoff,
                   let selectedPickupItem,
                   let selectedDropOffItem {
                    vm.getDirections(
                        from: selectedPickupItem,
                        to: selectedDropOffItem,
                        step: selectedStep)
                }
                if selectedStep == .request,
                   let selectedPickupItem,
                   let selectedDriverItem {
                    vm.getDirections(
                        from: selectedDriverItem,
                        to: selectedPickupItem,
                        step: .request)
                }
            }
            .onChange(of: vm.searchResultsForDrivers){
                // updateCameraPosition(focus: .locU, distance: 1429, heading: 92, pitch: 70)
            }
            .onChange(of: vm.searchResults){
                // updateCameraPosition(focus: .locU, distance: 4129, heading: 92, pitch: 70)
            }
            /*
            .onChange(of: selectedStep){
                withAnimation(.spring()){
                    switch selectedStep {
                    case .pickup:
                        // updateCameraPosition(focus: .locU, distance: 992, heading: 70, pitch: 60)
                    case .package:
                        if let selectedDriverItem {
                            // updateCameraPosition(focus: selectedDriverItem.placemark.coordinate, distance: 992, heading: 70, pitch: 60)
                        }else {
                            // updateCameraPosition(focus: .locU, distance: 2729, heading: 92, pitch: 70)
                        }
                    case .dropoff:
                        if let selectedDropOffItem {
                            // updateCameraPosition(focus: selectedDropOffItem.placemark.coordinate, distance: 992, heading: 70, pitch: 60)
                        }else {
                            // updateCameraPosition(focus: .locU, distance: 992, heading: 70, pitch: 60)
                        }
                        
                    case .request:
                        // updateCameraPosition(focus: .locU, distance: 3729, heading: 92, pitch: 70)
                    }
                }
            }
            .onChange(of: selectedDropOffItem){
                if let selectedDropOffItem {
                    // updateCameraPosition(focus: selectedDropOffItem.placemark.coordinate, distance: 3429, heading: 92, pitch: 60)
                }
            }
            .onChange(of: selectedDriverItem){
                if let selectedPickupItem,
                   let selectedDriverItem {
                    vm.getDirections(
                        from: selectedDriverItem,
                        to: selectedPickupItem,
                        step: .request)
                }
            }
            .onChange(of: selectedVehicle){oldV, newV in
                if newV != nil {
                    Task.detached{
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6.29) {
                            let randomIndex = Int.random(in: 0..<4)
                            selectedDriverItem = vm.searchResultsForDrivers[randomIndex]
                        }
                    }
                }
            }
            */
            .onChange(of: searchText) { oldT, newT in
                if selectedPickupItem != nil &&
                    selectedStep == .dropoff &&
                    newT.count > 3 {
                    searchTextPublisher.send(newT)
                }
            }
            .onReceive(
                searchTextPublisher
                    .debounce(for: .milliseconds(729), scheduler: DispatchQueue.main)
            ) { debouncedSearchText in
                if let selectedPickupItem {
                    selectedDropOffItem = nil
                    vm.searchLocations(for: debouncedSearchText, from: selectedPickupItem.placemark.coordinate)
                }
            }
    }
    
    private var pickupView: some View {
        Image("profil_photo_baris")
            .resizable()
            .scaledToFit()
            .frame(width: 48)
            .clipShape(Circle())
            .padding(4)
            .background(colorMyPin)
            .clipShape(Circle())
            .offset(y: -16)
            .overlay(alignment: .bottom) {
                Image(systemName: "triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(colorMyPin)
                    .frame(width: 24)
                    .scaleEffect(y: -1)
            }
            .offset(y: 16)
    }
    private var dropOffView: some View {
        Text("Drop\nOff")
            .foregroundStyle(.white)
            .font(.subheadline)
            .bold()
            .multilineTextAlignment(.center)
            .padding(7)
            .background(.black)
            .clipShape(Circle())
            .padding(4)
            .background(colorMyPin)
            .clipShape(Circle())
            .offset(y: -14)
            .overlay(alignment: .bottom) {
                Image(systemName: "triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(colorMyPin)
                    .frame(width: 24)
                    .scaleEffect(y: -1)
                
            }
    }
}

#Preview {
    NewMapView(vm: MapViewModel(),
               selectedPickupItem: .constant(nil),
               selectedDropOffItem:.constant(nil),
               selectedDriverItem: .constant(nil),
               selectedStep: .constant(.pickup),
               searchText: .constant(""),
               selectedVehicle: .constant(nil))
}
