//
//  camera.hpp
//  Cytrus
//
//  Created by Jarrod Norwell on 14/9/2026.
//

#include "core/frontend/camera/factory.h"
#include "core/frontend/camera/interface.h"

namespace Camera {
class iOSLeftRearCameraFactory : public CameraFactory {
public:
    ~iOSLeftRearCameraFactory() override;
    
    std::unique_ptr<CameraInterface> Create(const std::string& config,
                                            const Service::CAM::Flip& flip) override;
};

class iOSRightRearCameraFactory : public CameraFactory {
public:
    ~iOSRightRearCameraFactory() override;
    
    std::unique_ptr<CameraInterface> Create(const std::string& config,
                                            const Service::CAM::Flip& flip) override;
};
}

namespace Camera {
class iOSFrontCameraFactory : public CameraFactory {
public:
    ~iOSFrontCameraFactory() override;
    
    std::unique_ptr<CameraInterface> Create(const std::string& config,
                                            const Service::CAM::Flip& flip) override;
};
}

namespace Camera {
class iOSLeftRearCameraInterface : public CameraInterface {
public:
    ~iOSLeftRearCameraInterface() override;
    
    void StartCapture() override;
    void StopCapture() override;
    
    void SetResolution(const Service::CAM::Resolution& resolution) override;
    void SetFlip(Service::CAM::Flip flip) override;
    void SetEffect(Service::CAM::Effect effect) override;
    void SetFormat(Service::CAM::OutputFormat format) override;
    void SetFrameRate(Service::CAM::FrameRate frame_rate) override;
    std::vector<u16> ReceiveFrame() override;
    bool IsPreviewAvailable() override;
};

class iOSRightRearCameraInterface : public CameraInterface {
public:
    ~iOSRightRearCameraInterface() override;
    
    void StartCapture() override;
    void StopCapture() override;
    
    void SetResolution(const Service::CAM::Resolution& resolution) override;
    void SetFlip(Service::CAM::Flip flip) override;
    void SetEffect(Service::CAM::Effect effect) override;
    void SetFormat(Service::CAM::OutputFormat format) override;
    void SetFrameRate(Service::CAM::FrameRate frame_rate) override;
    std::vector<u16> ReceiveFrame() override;
    bool IsPreviewAvailable() override;
};

class iOSFrontCameraInterface : public CameraInterface {
public:
    ~iOSFrontCameraInterface() override;
    
    void StartCapture() override;
    void StopCapture() override;
    
    void SetResolution(const Service::CAM::Resolution& resolution) override;
    void SetFlip(Service::CAM::Flip flip) override;
    void SetEffect(Service::CAM::Effect effect) override;
    void SetFormat(Service::CAM::OutputFormat format) override;
    void SetFrameRate(Service::CAM::FrameRate frame_rate) override;
    std::vector<u16> ReceiveFrame() override;
    bool IsPreviewAvailable() override;
};
} // namespace Camera
