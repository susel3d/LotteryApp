//
//  CouponGenerator.swift
//  Lottery
//
//  Created by Łukasz Kmiotek on 11/05/2025.
//

import Combine

public struct GeneratedCoupon: Hashable {
    public init(value: [Int]) {
        self.value = value
    }
    
    public let value: [Int]
}

class CouponGenerator {
    private let inclusion: [[Int]]
    private let validNumbersCount: Int

    init(inclusion: [[Int]], exclusion: [Int], validNumbersCount: Int) {
        self.inclusion = inclusion.map {
            $0.filter { number in
                !exclusion.contains(number)
            }
        }
        self.validNumbersCount = validNumbersCount
    }

    func generateCouponsPublisher() -> AnyPublisher<GeneratedCoupon, Never> {
        let subject = PassthroughSubject<GeneratedCoupon, Never>()

        Task {
            while true {
                try? await Task.sleep(for: .seconds(0.05))
                Task {
                    if let coupon = prepareCoupon() {
                        subject.send(coupon)
                    }
                }
            }
            subject.send(completion: .finished)
        }
        return subject.eraseToAnyPublisher()
    }

    private func prepareCoupon() -> GeneratedCoupon? {
        var coupon: [Int] = []
        var randomNumber: Int
        for position in 0...validNumbersCount - 1 {
            if inclusion[position].isEmpty {
                return nil
            }
            repeat {
                randomNumber = inclusion[position].randomElement()!
            } while coupon.contains { $0 == randomNumber }
            coupon.append(randomNumber)
        }
        coupon.sort(by: <)
        return GeneratedCoupon(value: coupon)
    }
}
