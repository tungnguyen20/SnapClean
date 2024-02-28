//
//  HomeView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    
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
        .background(Image("bg"))
    }
}

#Preview {
    HomeView(viewModel: .init())
}

struct HomeSectionView: View {
    var section: HomeViewModel.Section
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.type.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("\(section.totalItems) items • \(section.totalSize / (1024 * 1024)) GB")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Button(action: {
                    
                }, label: {
                    Text("Review")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.brand)
                        .padding(16)
                        .background(Color.gray100)
                        .clipShape(Capsule())
                })
            }
            
//            LazyVGrid(columns: /*@START_MENU_TOKEN@*/[GridItem(.fixed(20))]/*@END_MENU_TOKEN@*/, content: {
//                /*@START_MENU_TOKEN@*/Text("Placeholder")/*@END_MENU_TOKEN@*/
//                Text("Placeholder")
//            })
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
