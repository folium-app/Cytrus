// Copyright Citra Emulator Project / Azahar Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include <SDL3/SDL.h>
#include "sdl_joystick.h"

typedef struct SDL_GamepadButtonBind {
    SDL_GamepadBindingType bindType;
    union {
        int button;
        int axis;
        struct {
            int hat;
            int hat_mask;
        } hat;
    } value;

} SDL_GamepadButtonBind;

/*
* Code used from sdl2-compat
https://github.com/libsdl-org/sdl2-compat/blob/main/src/sdl2_compat.c#L10315-L10348
*/
static SDL_GamepadButtonBind SDL_GamepadGetBindForAxis(SDL_Gamepad* controller, SDL_GamepadAxis axis) {
    SDL_GamepadButtonBind bind{};

    if (axis != SDL_GAMEPAD_AXIS_INVALID) {
        SDL_GamepadBinding** bindings = SDL_GetGamepadBindings(controller, nullptr);
        if (bindings) {
            for (int i = 0; bindings[i]; ++i) {
                const SDL_GamepadBinding* binding = bindings[i];
                if (binding->output_type == SDL_GAMEPAD_BINDTYPE_AXIS &&
                    binding->output.axis.axis == axis) {
                    bind.bindType = static_cast<SDL_GamepadBindingType>(binding->input_type);
                    if (binding->input_type == SDL_GAMEPAD_BINDTYPE_AXIS) {
                        /* FIXME: There might be multiple axes bound now that we have axis ranges...
                         */
                        bind.value.axis = binding->input.axis.axis;
                    } else if (binding->input_type == SDL_GAMEPAD_BINDTYPE_BUTTON) {
                        bind.value.button = binding->input.button;
                    } else if (binding->input_type == SDL_GAMEPAD_BINDTYPE_HAT) {
                        bind.value.hat.hat = binding->input.hat.hat;
                        bind.value.hat.hat_mask = binding->input.hat.hat_mask;
                    }
                    break;
                }
            }
            SDL_free(bindings);
        }
    }

    return bind;
}

/*
* Code used from sdl2-compat
https://github.com/libsdl-org/sdl2-compat/blob/main/src/sdl2_compat.c#L10350-L10382
*/
static SDL_GamepadButtonBind SDL_GamepadGetBindForButton(SDL_Gamepad* controller, SDL_GamepadButton button) {
    SDL_GamepadButtonBind bind{};

    if (button != SDL_GAMEPAD_BUTTON_INVALID) {
        SDL_GamepadBinding** bindings = SDL_GetGamepadBindings(controller, nullptr);
        if (bindings) {
            for (int i = 0; bindings[i]; ++i) {
                const SDL_GamepadBinding* binding = bindings[i];
                if (binding->output_type == SDL_GAMEPAD_BINDTYPE_BUTTON &&
                    binding->output.button == button) {
                    bind.bindType = static_cast<SDL_GamepadBindingType>(binding->input_type);
                    if (binding->input_type == SDL_GAMEPAD_BINDTYPE_AXIS) {
                        bind.value.axis = binding->input.axis.axis;
                    } else if (binding->input_type == SDL_GAMEPAD_BINDTYPE_BUTTON) {
                        bind.value.button = binding->input.button;
                    } else if (binding->input_type == SDL_GAMEPAD_BINDTYPE_HAT) {
                        bind.value.hat.hat = binding->input.hat.hat;
                        bind.value.hat.hat_mask = binding->input.hat.hat_mask;
                    }
                    break;
                }
            }
            SDL_free(bindings);
        }
    }

    return bind;
}

namespace InputCommon::SDL {

SDLJoystick::SDLJoystick(std::string guid_, int port_, SDL_Joystick* joystick,
                         SDL_Gamepad* game_controller)
    : guid{std::move(guid_)}, port{port_}, sdl_joystick{joystick, &SDL_CloseJoystick},
      sdl_controller{game_controller, &SDL_CloseGamepad} {
    EnableMotion();
    CreateControllerButtonMap();
}

bool SDLJoystick::IsButtonMappedToController(int button) const {
    return mapped_joystick_buttons.count(button) > 0;
}

void SDLJoystick::EnableMotion() {
    if (!sdl_controller) {
        return;
    }
#if SDL_VERSION_ATLEAST(2, 0, 14)
    SDL_Gamepad* controller = sdl_controller.get();

    if (HasMotion()) {
        SDL_SetGamepadSensorEnabled(controller, SDL_SENSOR_ACCEL, false);
        SDL_SetGamepadSensorEnabled(controller, SDL_SENSOR_GYRO, false);
    }
    has_accel = SDL_GamepadHasSensor(controller, SDL_SENSOR_ACCEL) == true;
    has_gyro = SDL_GamepadHasSensor(controller, SDL_SENSOR_GYRO) == true;
    if (has_accel) {
        SDL_SetGamepadSensorEnabled(controller, SDL_SENSOR_ACCEL, true);
    }
    if (has_gyro) {
        SDL_SetGamepadSensorEnabled(controller, SDL_SENSOR_GYRO, true);
    }
#endif
}

bool SDLJoystick::HasMotion() const {
    return has_gyro || has_accel;
}

bool SDLJoystick::GetButton(int button, bool isController) const {
    if (!sdl_joystick)
        return false;
    if (isController)
        return SDL_GetGamepadButton(sdl_controller.get(),
                                           static_cast<SDL_GamepadButton>(button));
    return SDL_GetJoystickButton(sdl_joystick.get(), button) != 0;
}

float SDLJoystick::GetAxis(int axis, bool isController) const {
    if (!sdl_joystick)
        return 0.0;
    if (isController)
        return SDL_GetGamepadAxis(sdl_controller.get(),
                                         static_cast<SDL_GamepadAxis>(axis)) /
               32767.0f;
    return SDL_GetJoystickAxis(sdl_joystick.get(), axis) / 32767.0f;
}

std::tuple<float, float> SDLJoystick::GetAnalog(int axis_x, int axis_y, bool isController) const {
    float x = GetAxis(axis_x, isController);
    float y = GetAxis(axis_y, isController);
    y = -y; // 3DS uses an y-axis inverse from SDL

    // Make sure the coordinates are in the unit circle,
    // otherwise normalize it.
    float r = x * x + y * y;
    if (r > 1.0f) {
        r = std::sqrt(r);
        x /= r;
        y /= r;
    }

    return std::make_tuple(x, y);
}

bool SDLJoystick::GetHatDirection(int hat, Uint8 direction) const {
    // no need to worry about gamecontroller here - that api treats hats as buttons
    if (!sdl_joystick)
        return false;
    return SDL_GetJoystickHat(sdl_joystick.get(), hat) == direction;
}

void SDLJoystick::SetTouchpad(float x, float y, int touchpad, bool down) {
    std::lock_guard lock{mutex};
    state.touchpad[touchpad] = std::make_tuple(x, y, down);
}

void SDLJoystick::SetAccel(const float x, const float y, const float z) {
    std::lock_guard lock{mutex};
    state.accel.x = x;
    state.accel.y = y;
    state.accel.z = z;
}
void SDLJoystick::SetGyro(const float pitch, const float yaw, const float roll) {
    std::lock_guard lock{mutex};
    state.gyro.x = pitch;
    state.gyro.y = yaw;
    state.gyro.z = roll;
}
std::tuple<Common::Vec3<float>, Common::Vec3<float>> SDLJoystick::GetMotion() const {
    std::lock_guard lock{mutex};
    return std::make_tuple(state.accel, state.gyro);
}

/**
 * The guid of the joystick
 */
const std::string& SDLJoystick::GetGUID() const {
    return guid;
}

/**
 * The number of joystick from the same type that were connected before this joystick
 */
int SDLJoystick::GetPort() const {
    return port;
}

std::tuple<float, float, float> SDLJoystick::GetTouch(int pad) const {
    return state.touchpad.at(pad);
}

SDL_Joystick* SDLJoystick::GetSDLJoystick() const {
    return sdl_joystick.get();
}

SDL_Gamepad* SDLJoystick::GetSDLGameController() const {
    return sdl_controller.get();
}

void SDLJoystick::SetSDLJoystick(SDL_Joystick* joystick, SDL_Gamepad* controller) {
    sdl_joystick.reset(joystick);
    sdl_controller.reset(controller);
}

void SDLJoystick::CreateControllerButtonMap() {
    mapped_joystick_buttons.clear();

    if (!sdl_controller) {
        return; // Not a controller, no mapped buttons
    }

    // Check all controller buttons
    for (int i = 0; i < SDL_GAMEPAD_BUTTON_COUNT; i++) {
        int count{0};
        auto binds = SDL_GetGamepadBindings(sdl_controller.get(), &count);
        auto bind = binds[i];

        if (bind->output_type == SDL_GAMEPAD_BINDTYPE_BUTTON) {
            mapped_joystick_buttons.insert(bind->output.button);
        }
    }

    // Also check trigger axes that might be buttons
    auto lt_bind =
        SDL_GamepadGetBindForAxis(sdl_controller.get(), SDL_GAMEPAD_AXIS_LEFT_TRIGGER);
    if (lt_bind.bindType == SDL_GAMEPAD_BINDTYPE_BUTTON) {
        mapped_joystick_buttons.insert(lt_bind.value.button);
    }

    auto rt_bind =
        SDL_GamepadGetBindForAxis(sdl_controller.get(), SDL_GAMEPAD_AXIS_RIGHT_TRIGGER);
    if (rt_bind.bindType == SDL_GAMEPAD_BINDTYPE_BUTTON) {
        mapped_joystick_buttons.insert(rt_bind.value.button);
    }
}

} // namespace InputCommon::SDL
