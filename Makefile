build:
	swift build -c release

test:
	@DEV_DIR="$$(xcode-select -p 2>/dev/null || true)"; \
	case "$$DEV_DIR" in \
	  */Xcode*.app/Contents/Developer) swift test ;; \
	  *) \
	    F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks; \
	    L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib; \
	    if [ ! -d "$$F/Testing.framework" ] || [ ! -f "$$L/lib_TestingInterop.dylib" ]; then \
	      echo "error: swift-testing support not found:" >&2; \
	      echo "  $$F/Testing.framework" >&2; \
	      echo "  $$L/lib_TestingInterop.dylib" >&2; \
	      echo "See docs/adr/0002-tests-run-without-xcode.md" >&2; \
	      exit 1; \
	    fi; \
	    swift test \
	      -Xswiftc -F -Xswiftc "$$F" \
	      -Xlinker -F -Xlinker "$$F" \
	      -Xlinker -rpath -Xlinker "$$F" \
	      -Xlinker -rpath -Xlinker "$$L"; \
	    ;; \
	esac

run:
	swift run machscope quick /Applications


