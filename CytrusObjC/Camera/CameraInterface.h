//
//  CameraInterface.h
//  Cytrus
//
//  Created by Jarrod Norwell on 27/8/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#include "core/frontend/camera/interface.h"

namespace Camera {

/// An abstract class standing for a camera. All camera implementations should inherit from this.
class iOSCameraInterface : public CameraInterface {
public:
    ~iOSCameraInterface() override;

    /// Starts the camera for video capturing.
    void StartCapture() override;

    /// Stops the camera for video capturing.
    void StopCapture() override;

    /**
     * Sets the video resolution from raw CAM service parameters.
     * For the meaning of the parameters, please refer to Service::CAM::Resolution. Note that the
     * actual camera implementation doesn't need to respect all the parameters. However, the width
     * and the height parameters must be respected and be used to determine the size of output
     * frames.
     * @param resolution The resolution parameters to set
     */
    void SetResolution(const Service::CAM::Resolution& resolution) override;

    /**
     * Configures how received frames should be flipped by the camera.
     * @param flip Flip applying to the frame
     */
    void SetFlip(Service::CAM::Flip flip) override;

    /**
     * Configures what effect should be applied to received frames by the camera.
     * @param effect Effect applying to the frame
     */
    void SetEffect(Service::CAM::Effect effect) override;

    /**
     * Sets the output format of the all frames received after this function is called.
     * @param format Output format of the frame
     */
    void SetFormat(Service::CAM::OutputFormat format) override;

    /**
     * Sets the recommended framerate of the camera.
     * @param frame_rate Recommended framerate
     */
    void SetFrameRate(Service::CAM::FrameRate frame_rate) override;

    /**
     * Receives a frame from the camera.
     * This function should be only called between a StartCapture call and a StopCapture call.
     * @returns A std::vector<u16> containing pixels. The total size of the vector is width * height
     *     where width and height are set by a call to SetResolution.
     */
    std::vector<u16> ReceiveFrame() override;

    /**
     * Test if the camera is opened successfully and can receive a preview frame. Only used for
     * preview. This function should be only called between a StartCapture call and a StopCapture
     * call.
     * @returns true if the camera is opened successfully and false otherwise
     */
    bool IsPreviewAvailable() override;
};

} // namespace Camera
