cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "warpgate_engine")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../../../rust warpgate_engine "")

set(warpgate_engine_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
