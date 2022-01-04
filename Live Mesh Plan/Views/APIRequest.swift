//
//  APIRequest.swift
//  Live Mesh
//
//  Created by Indrajit Chavda on 19/10/21.
//

import Foundation

class APIRequest {
    static func request(with data: Data,
                        completionHandler: @escaping (_ error: String?) -> Void) {
        let url = URL(string: "https:www.google.com")!
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(NSUUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = NSMutableData()
        body.append(NSString(format:"Content-Disposition: form-data; name=\"lidar_data\"; filename=\"mesh.obj\"\r\n").data(using: String.Encoding.utf8.rawValue)!)
        body.append(NSString(format: "Content-Type: application/octet-stream\r\n\r\n").data(using: String.Encoding.utf8.rawValue)!)
        body.append(data)
        body.append(NSString(format: "\r\n--%@\r\n", boundary).data(using: String.Encoding.utf8.rawValue)!)
        request.httpBody = body as Data
        
        let task =  URLSession.shared.dataTask(with: request as URLRequest,
                                               completionHandler: {
            (data, response, error) -> Void in
            if let error = error {
                completionHandler(error.localizedDescription)
            } else {
                completionHandler(nil)
            }
        })
        task.resume()
    }
}
