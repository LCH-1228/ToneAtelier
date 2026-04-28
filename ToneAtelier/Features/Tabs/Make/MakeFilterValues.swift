//
//  MakeFilterValues.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation

extension MakeFilterValues {
  nonisolated static let `default` = MakeFilterValues()

  var jsonValue: JSONValue {
    .object([
      "brightness": .number(brightness),
      "exposure": .number(exposure),
      "contrast": .number(contrast),
      "saturation": .number(saturation),
      "sharpness": .number(sharpness),
      "blur": .number(blur),
      "vignette": .number(vignette),
      "noise_reduction": .number(noiseReduction),
      "highlights": .number(highlights),
      "shadows": .number(shadows),
      "temperature": .number(temperature),
      "black_point": .number(blackPoint)
    ])
  }
}
