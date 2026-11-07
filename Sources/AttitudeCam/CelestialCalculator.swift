import Foundation

struct CelestialPosition: Sendable {
    let sunAzimuth: Double
    let sunElevation: Double
    let moonAzimuth: Double
    let moonElevation: Double
}

enum CelestialCalculator {
    /// Computes real-time Sun and Moon azimuth and elevation angles (in degrees)
    static func calculate(date: Date, latitude: Double, longitude: Double) -> CelestialPosition {
        let (sunAz, sunEl) = calculateSun(date: date, lat: latitude, lon: longitude)
        let (moonAz, moonEl) = calculateMoon(date: date, lat: latitude, lon: longitude)
        return CelestialPosition(
            sunAzimuth: sunAz,
            sunElevation: sunEl,
            moonAzimuth: moonAz,
            moonElevation: moonEl
        )
    }
    
    // MARK: - Solar Position Algorithm
    private static func calculateSun(date: Date, lat: Double, lon: Double) -> (Double, Double) {
        let jd = julianDate(from: date)
        let n = jd - 2451545.0
        let L = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360.0)
        let g = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let lambda = (L + 1.915 * sin(g) + 0.020 * sin(2 * g)) * .pi / 180.0
        let epsilon = (23.439 - 0.0000004 * n) * .pi / 180.0
        
        let ra = atan2(cos(epsilon) * sin(lambda), cos(lambda))
        let dec = asin(sin(epsilon) * sin(lambda))
        
        let gmst = (18.697374558 + 24.06570982441908 * n).truncatingRemainder(dividingBy: 24.0)
        let lmst = ((gmst * 15.0 + lon).truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let ha = lmst - ra
        
        let latR = lat * .pi / 180.0
        let sinEl = sin(latR) * sin(dec) + cos(latR) * cos(dec) * cos(ha)
        let elevation = asin(max(-1.0, min(1.0, sinEl))) * 180.0 / .pi
        
        let cosAz = (sin(dec) - sin(latR) * sin(elevation * .pi / 180.0)) / (cos(latR) * cos(elevation * .pi / 180.0))
        var azimuth = acos(max(-1.0, min(1.0, cosAz))) * 180.0 / .pi
        if sin(ha) > 0 {
            azimuth = 360.0 - azimuth
        }
        
        return (round(azimuth * 10) / 10, round(elevation * 10) / 10)
    }
    
    // MARK: - Lunar Position Algorithm
    private static func calculateMoon(date: Date, lat: Double, lon: Double) -> (Double, Double) {
        let jd = julianDate(from: date)
        let T = (jd - 2451545.0) / 36525.0
        
        let L_prime = (218.3164477 + 481267.88123421 * T).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let D = (297.8501921 + 445267.1114034 * T).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let M = (357.5291092 + 35999.0502909 * T).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let M_prime = (134.9633964 + 477198.8675055 * T).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let F = (93.2720950 + 483202.0175233 * T).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        
        let l = L_prime + (6.289 * sin(M_prime) - 1.274 * sin(2*D - M_prime) + 0.658 * sin(2*D) - 0.214 * sin(2*M_prime) - 0.186 * sin(M)) * .pi / 180.0
        let b = (5.128 * sin(F) + 0.280 * sin(M_prime + F) + 0.277 * sin(M_prime - F) + 0.173 * sin(2*D - F)) * .pi / 180.0
        
        let epsilon = (23.439 - 0.013 * T) * .pi / 180.0
        let ra = atan2(sin(l) * cos(epsilon) - tan(b) * sin(epsilon), cos(l))
        let dec = asin(sin(b) * cos(epsilon) + cos(b) * sin(epsilon) * sin(l))
        
        let n = jd - 2451545.0
        let gmst = (18.697374558 + 24.06570982441908 * n).truncatingRemainder(dividingBy: 24.0)
        let lmst = ((gmst * 15.0 + lon).truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        let ha = lmst - ra
        
        let latR = lat * .pi / 180.0
        let sinEl = sin(latR) * sin(dec) + cos(latR) * cos(dec) * cos(ha)
        let elevation = asin(max(-1.0, min(1.0, sinEl))) * 180.0 / .pi
        
        let cosAz = (sin(dec) - sin(latR) * sin(elevation * .pi / 180.0)) / (cos(latR) * cos(elevation * .pi / 180.0))
        var azimuth = acos(max(-1.0, min(1.0, cosAz))) * 180.0 / .pi
        if sin(ha) > 0 {
            azimuth = 360.0 - azimuth
        }
        
        return (round(azimuth * 10) / 10, round(elevation * 10) / 10)
    }
    
    private static func julianDate(from date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        let comp = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        
        var y = comp.year!
        var m = comp.month!
        let dayFrac = Double(comp.day!) + (Double(comp.hour!) + Double(comp.minute!) / 60.0 + Double(comp.second!) / 3600.0) / 24.0
        
        if m <= 2 {
            y -= 1
            m += 12
        }
        
        let A = floor(Double(y) / 100.0)
        let B = 2.0 - A + floor(A / 4.0)
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + dayFrac + B - 1524.5
    }
}
