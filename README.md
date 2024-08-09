<center><a href="https://qlibs.github.io"><img src="https://qlibs.github.io/img/qlibs_logo.png" /></a></center>

---

```
CPMAddPackage(
  Name qlibs
  GITHUB_REPOSITORY qlibs/qlibs
  GIT_TAG v1.0.0
)
add_library(qlibs INTERFACE)
target_include_directories(qlibs SYSTEM INTERFACE ${qlibs_SOURCE_DIR})
add_library(qlibs::qlibs ALIAS qlibs)
```

```
target_link_libraries(${PROJECT_NAME} qlibs::qlibs);
```
