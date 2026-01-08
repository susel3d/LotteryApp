//
//  CouponController.swift
//  Lottery
//
//  Created by Łukasz Kmiotek on 09/02/2025.
//

import Combine
import LotteryFramework
import Foundation

enum ControllerError: Error {
    case timeout
}

public class CouponController {

    @Published public var commonDataReady = false
    @Published public var progress: Double = 0
    @Published public var generatedCoupons: [GeneratedCoupon] = []

    private var subscriptions = Set<AnyCancellable>()
    private let drawType: DrawType
    private var couponModels: CouponGeneratorModels

    public var validNumbersCount: Int {
        drawType.validNumbersCount
    }

    public init(drawType: DrawType) {
        self.drawType = drawType
        couponModels = CouponGeneratorModels(drawType: drawType)
        bindForDataReadiness()
    }

    private func bindForDataReadiness() {
        couponModels.$modelsReady
            .assign(to: \.commonDataReady, on: self)
            .store(in: &subscriptions)
    }

    public func cancelGeneration() {
        self.progress = 0
        subscriptions.removeAll()
    }

    public func generateCoupons(timeout: TimeInterval,
                         couponDistance: Int,
                         couponsCount: Int,
                         historyDeepth: Int,
                         standardDevFactor: Double) {

        guard commonDataReady else {
            return
        }

        generatedCoupons.removeAll()
        progress = 0

        let inclusionSet = couponModels.getInclusionSet(
            historyDeepth: historyDeepth,
            standardDevFactor: standardDevFactor)
        
        let exclusionSet = couponModels.getExclusionSet()

        Publishers.CombineLatest(inclusionSet, exclusionSet)
            .setFailureType(to: ControllerError.self)
            .timeout(.seconds(timeout), scheduler: RunLoop.main, customError: {
                ControllerError.timeout
            })
            .compactMap(unwrapResults)
            .flatMap { result1, result2 in
                let generator = CouponGenerator(
                    inclusion: result1,
                    exclusion: result2,
                    validNumbersCount: self.validNumbersCount
                )
                return generator.generateCouponsPublisher()
            }
            .filter({ coupon in
                self.couponModels.isResultInFilterScope(coupon.value)
            })
            .filterOutCouponsByDistance(couponDistance)
            .prefix(couponsCount)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    self?.progress = 1
                case .failure(let error):
                    self?.progress = 1
                    print(error)
                }
            }, receiveValue: { [weak self] coupon in
                print("\(coupon.value )")
                self?.generatedCoupons.append(coupon)
                self?.progress += 1.0 / Double(couponsCount)
            })
            .store(in: &subscriptions)
    }

    func saveCoupon() {
//        let nextIdx = (savedCoupons.last?.idx ?? 0) + 1
//        let numbers = futureResult.numbersAsString()
//        model.saveCoupon(idx: nextIdx, numbers: numbers)
//        loadCoupons()
    }

    //    func saveCoupon() {
    //        let nextIdx = (savedCoupons.last?.idx ?? 0) + 1
    //        let numbers = futureResult.numbersAsString()
    //        model.saveCoupon(idx: nextIdx, numbers: numbers)
    //        loadCoupons()
    //    }
    //
    //    func loadCoupons() {
    //        model.loadCoupons()
    //    }
    //
    //    func clearSavedCoupons() {
    //        model.clearSavedCoupons()
    //        model.loadCoupons()
    //    }
    //
    //    func clearSavedCoupon(_ couponIdx: Int) {
    //        model.clearSavedCoupon(couponIdx)
    //        model.loadCoupons()
    //    }

    func loadCoupons() {
        //commonDataModel.loadCoupons()
    }

    func clearSavedCoupons() {
        //commonDataModel.clearSavedCoupons()
        //commonDataModel.loadCoupons()
    }

    func clearSavedCoupon(_ couponIdx: Int) {
        //commonDataModel.clearSavedCoupon(couponIdx)
        //commonDataModel.loadCoupons()
    }
}

// MARK: - Helpers

func unwrapResults<T, U>(value1: T?, value2: U?) -> (T, U)? {
    guard let value1, let value2 else {
        return nil
    }
    return (value1, value2)
}

extension Publisher where Output == GeneratedCoupon {

}

extension Publisher where Output == GeneratedCoupon {
    func filterOutCouponsByDistance(_ distance: Int) -> AnyPublisher<GeneratedCoupon, Failure> {
        self
            .scan((Set<Set<Int>>(), Optional<GeneratedCoupon>.none)) { state, coupon in
                var (seenSets, _) = state
                let numberSet = Set(coupon.value)

                var skipSet: Bool

                if distance == 0 {
                    skipSet = seenSets.contains(numberSet)
                } else {
                    skipSet = !seenSets.filter( { seenSet in
                        return numberSet.subtracting(seenSet).count <= distance
                    }).isEmpty
                }

                if skipSet {
                    return (seenSets, nil)
                } else {
                    seenSets.insert(numberSet)
                    return (seenSets, coupon)
                }
            }
            .compactMap { $0.1 }
            .eraseToAnyPublisher()
    }
}
