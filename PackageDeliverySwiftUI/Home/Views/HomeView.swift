//
//  HomeView.swift
//  PackageDeliverySwiftUI
//
//  Created by Baris OZGEN on 6.06.2023.
//

import SwiftUI
import MapKit


struct HomeView: View {
    
    @State private var selectedItem: MKMapItem?
    
    
    var body: some View {
        ZStack{
            MapMainView()
                .sheet(isPresented: .constant(true)){
                    /*PackageSelectionView()
                        .presentationDetents([
                            .height(429),
                            .fraction(0.54)])*/
                    VehicleSelectionView(selectedPackage: .l, km: 14.29)
                        .presentationDetents([
                            .height(529),
                            .fraction(0.62)])
                }
            //MapView(selectedItem: $selectedItem)
            //LocationDetailView()
            Text("\(selectedItem?.name ?? "none")")
            
        }
    }
}

#Preview {
    HomeView()
}
