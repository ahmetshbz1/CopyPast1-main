import Foundation

// Zaman gösterimi fonksiyonu
public func timeAgoDisplay(date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
    
    if let day = components.day, day > 0 {
        return "\(day)g önce"
    } else if let hour = components.hour, hour > 0 {
        return "\(hour)s önce"
    } else if let minute = components.minute, minute > 0 {
        return "\(minute)d önce"
    } else {
        return "Şimdi"
    }
}