//
//  HomeView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI

struct HomeView: View {
    var viewModel: HomeViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text("SnapClean")
                    .font(Font.system(size: 24, weight: .bold))
                Spacer()
                Image("setting")
            }
            
            ScrollView {
                ForEach(viewModel.sections) { section in
                    HomeSectionView(section: section)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    HomeView(viewModel: .init())
}
