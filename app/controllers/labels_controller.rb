class LabelsController < ApplicationController
  def get_factor(um = nil)
    case um
    when "in"
      return 2.54

    when "lb"
      return 0.454

    # Exception
    else
      return 1
    end
  end

  def get_labels(source = nil)
    source = "data/labels.json" if source == nil
    labels = File.file?(source) ? JSON.parse(File.read(source), object_class: OpenStruct) : []
    fedex = Fedex::Shipment.new(:key            => 'O21wEWKhdDn2SYyb',
                                :password       => 'db0SYxXWWh0bgRSN7Ikg9Vunz',
                                :account_number => '510087780',
                                :meter          => '119009727',
                                :mode           => 'test')

    # Apply changes on data labels
    labels.each do |label|
      # Distance units and values
      label.parcel["distance_unit"].downcase!

      # Converts values if not "cm"
      if label.parcel["distance_unit"] != "cm"
        factor = get_factor(label.parcel["distance_unit"])

        label.parcel["length"] *= factor
        label.parcel["width"] *= factor
        label.parcel["height"] *= factor
        label.parcel["distance_unit"] = "cm"
      end

      # Gets volumetric weight
      label.parcel["volumetric_weight"] = label.parcel["length"] * label.parcel["width"] * label.parcel["height"] / 5000.0
      label.parcel["volumetric_weight_rounded"] = label.parcel["volumetric_weight"].ceil.to_f

      # Mass units and values
      label.parcel["mass_unit"].downcase!

      # Converts values if not "kg"
      if label.parcel["mass_unit"] != "kg"
        label.parcel["weight"] *= get_factor(label.parcel["mass_unit"])
        label.parcel["mass_unit"] = "kg"
      end

      label.parcel["weight_rounded"] = label.parcel["weight"].ceil.to_f

      # Calculate total weight
      label.parcel["total_weight"] = label.parcel["weight_rounded"] > label.parcel["volumetric_weight_rounded"] ? label.parcel["weight_rounded"]
                                                                                                                : label.parcel["volumetric_weight_rounded"]

      # ----------
      # Get Fedex info
      result = fedex.track(:tracking_number => label["tracking_number"])
      label.parcel["fedex"] = {}

      if result != nil
        track = result.first

        label.parcel["fedex"] = {}
        label.parcel["fedex"]["weight"] = track.details[:package_weight][:value].to_f
        label.parcel["fedex"]["units"] = track.details[:package_weight][:units].downcase

        # Converts values if not "kg"
        if label.parcel["fedex"]["units"] != "kg"
          label.parcel["fedex"]["weight"] *= get_factor(label.parcel["fedex"]["units"])
          label.parcel["fedex"]["units"] = "kg"
        end
      end
    end

    return labels
  end

  def index
    @labels = get_labels
  end
end
