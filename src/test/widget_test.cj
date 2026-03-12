internal package cli.test

import cli.*

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ===============================================================
// Spinner 测试
// ===============================================================
@Test
class SpinnerTest {
    @TestCase
    func testDefaultSpinner() {
        let s = Spinner()
        @Assert(!s.isFinished())
        let frame = s.currentFrame()
        @Assert(frame == "⠋")
    }

    @TestCase
    func testSpinnerTick() {
        let s = Spinner()
        s.tick()
        @Assert(s.currentFrame() == "⠙")
        s.tick()
        @Assert(s.currentFrame() == "⠹")
    }

    @TestCase
    func testSpinnerWrapsAround() {
        let s = Spinner()
        // Dots 有 10 帧，tick 10 次回到第一帧
        var i: Int64 = 0
        while (i < 10) {
            s.tick()
            i++
        }
        @Assert(s.currentFrame() == "⠋")
    }

    @TestCase
    func testSpinnerMessage() {
        let s = Spinner().message("Loading...")
        let rendered = s.render()
        @Assert(rendered.contains("Loading..."))
        @Assert(rendered.contains("⠋"))
    }

    @TestCase
    func testSpinnerFinish() {
        let s = Spinner().message("Loading")
        s.finish()
        @Assert(s.isFinished())
        @Assert(s.render().contains("✓"))
    }

    @TestCase
    func testSpinnerFinishWithMessage() {
        let s = Spinner()
        s.finish(message: "Done!")
        @Assert(s.render() == "✓ Done!")
    }

    @TestCase
    func testSpinnerReset() {
        let s = Spinner()
        s.tick().tick().tick()
        s.finish()
        s.reset()
        @Assert(!s.isFinished())
        @Assert(s.currentFrame() == "⠋")
    }

    @TestCase
    func testLineStyle() {
        let s = Spinner(style: Line)
        @Assert(s.currentFrame() == "-")
        s.tick()
        @Assert(s.currentFrame() == "\\")
    }

    @TestCase
    func testArrowStyle() {
        let s = Spinner(style: Arrow)
        @Assert(s.currentFrame() == "←")
    }

    @TestCase
    func testSimpleStyle() {
        let s = Spinner(style: Simple)
        @Assert(s.currentFrame() == ".")
        s.tick()
        @Assert(s.currentFrame() == "o")
        s.tick()
        @Assert(s.currentFrame() == "O")
    }
}

// ===============================================================
// ProgressBar 测试
// ===============================================================
@Test
class ProgressBarTest {
    @TestCase
    func testProgressBarInit() {
        let bar = ProgressBar(100)
        @Assert(bar.getCurrent() == 0)
        @Assert(bar.getTotal() == 100)
        @Assert(bar.percent() == 0)
        @Assert(!bar.isComplete())
    }

    @TestCase
    func testProgressAdvance() {
        let bar = ProgressBar(100)
        bar.advance()
        @Assert(bar.getCurrent() == 1)
        bar.advance(delta: 9)
        @Assert(bar.getCurrent() == 10)
        @Assert(bar.percent() == 10)
    }

    @TestCase
    func testProgressSet() {
        let bar = ProgressBar(100)
        bar.set(50)
        @Assert(bar.getCurrent() == 50)
        @Assert(bar.percent() == 50)
    }

    @TestCase
    func testProgressClamp() {
        let bar = ProgressBar(100)
        bar.set(200)
        @Assert(bar.getCurrent() == 100)
        bar.set(-5)
        @Assert(bar.getCurrent() == 0)
    }

    @TestCase
    func testProgressFinish() {
        let bar = ProgressBar(100)
        bar.finish()
        @Assert(bar.getCurrent() == 100)
        @Assert(bar.percent() == 100)
        @Assert(bar.isComplete())
    }

    @TestCase
    func testProgressRender() {
        let bar = ProgressBar(100).width(10)
        bar.set(50)
        let rendered = bar.render()
        @Assert(rendered.contains("50%"))
        @Assert(rendered.contains("50/100"))
        @Assert(rendered.contains("█"))
        @Assert(rendered.contains("░"))
    }

    @TestCase
    func testProgressRenderFull() {
        let bar = ProgressBar(100).width(10)
        bar.finish()
        let rendered = bar.render()
        @Assert(rendered.contains("100%"))
        @Assert(!rendered.contains("░"))
    }

    @TestCase
    func testProgressCustomChars() {
        let bar = ProgressBar(10).width(10).filledChar("#").emptyChar("-")
        bar.set(5)
        let rendered = bar.render()
        @Assert(rendered.contains("#"))
        @Assert(rendered.contains("-"))
    }

    @TestCase
    func testProgressPrefix() {
        let bar = ProgressBar(100).prefix("Downloading")
        let rendered = bar.render()
        @Assert(rendered.contains("Downloading"))
    }

    @TestCase
    func testProgressHidePercent() {
        let bar = ProgressBar(100).showPercent(false)
        bar.set(50)
        let rendered = bar.render()
        @Assert(!rendered.contains("%"))
    }

    @TestCase
    func testProgressZeroTotal() {
        let bar = ProgressBar(0)
        @Assert(bar.percent() == 100)
        @Assert(bar.isComplete())
    }
}

// ===============================================================
// Confirm 组件测试
// ===============================================================
@Test
class ConfirmWidgetTest {
    @TestCase
    func testConfirmYes() {
        let mock = InputMock().addLine("y")
        let c = Confirm("Delete?")
        @Assert(c.run(mock))
    }

    @TestCase
    func testConfirmNo() {
        let mock = InputMock().addLine("n")
        let c = Confirm("Delete?")
        @Assert(!c.run(mock))
    }

    @TestCase
    func testConfirmDefaultTrue() {
        let mock = InputMock().addLine("")
        let c = Confirm("Continue?").defaultValue(true)
        @Assert(c.run(mock))
    }

    @TestCase
    func testConfirmDefaultFalse() {
        let mock = InputMock().addLine("")
        let c = Confirm("Continue?").defaultValue(false)
        @Assert(!c.run(mock))
    }

    @TestCase
    func testConfirmEOF() {
        let mock = InputMock()
        let c = Confirm("Continue?").defaultValue(true)
        @Assert(c.run(mock))
    }

    @TestCase
    func testConfirmRender() {
        let c = Confirm("Save?").defaultValue(true)
        let text = c.render()
        @Assert(text.contains("Save?"))
        @Assert(text.contains("[Y/n]"))
    }

    @TestCase
    func testConfirmRenderNoDefault() {
        let c = Confirm("Save?")
        let text = c.render()
        @Assert(text.contains("[y/N]"))
    }
}

// ===============================================================
// Select 组件测试
// ===============================================================
@Test
class SelectWidgetTest {
    @TestCase
    func testSelectByNumber() {
        let mock = InputMock().addLine("2")
        let s = Select("Pick:")
            .options(["Apple", "Banana", "Cherry"])
        match (s.run(mock)) {
            case Some(v) => @Assert(v == "Banana")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testSelectByText() {
        let mock = InputMock().addLine("cherry")
        let s = Select("Pick:")
            .options(["Apple", "Banana", "Cherry"])
        match (s.run(mock)) {
            case Some(v) => @Assert(v == "Cherry")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testSelectInvalid() {
        let mock = InputMock().addLine("99")
        let s = Select("Pick:").options(["A", "B"])
        @Assert(s.run(mock).isNone())
    }

    @TestCase
    func testSelectDefault() {
        let mock = InputMock().addLine("")
        let s = Select("Pick:")
            .options(["A", "B", "C"])
            .defaultOption(2)
        match (s.run(mock)) {
            case Some(v) => @Assert(v == "B")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testSelectEOFWithDefault() {
        let mock = InputMock()
        let s = Select("Pick:")
            .options(["X", "Y"])
            .defaultOption(1)
        match (s.run(mock)) {
            case Some(v) => @Assert(v == "X")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testSelectRender() {
        let s = Select("Choose:")
            .options(["Red", "Green", "Blue"])
            .defaultOption(2)
        let text = s.render()
        @Assert(text.contains("Choose:"))
        @Assert(text.contains("1. Red"))
        @Assert(text.contains("> 2. Green"))
        @Assert(text.contains("3. Blue"))
    }

    @TestCase
    func testSelectOptionCount() {
        let s = Select("Q").option("A").option("B")
        @Assert(s.optionCount() == 2)
    }
}

// ===============================================================
// MultiSelect 组件测试
// ===============================================================
@Test
class MultiSelectWidgetTest {
    @TestCase
    func testMultiSelectSingle() {
        let mock = InputMock().addLine("2")
        let ms = MultiSelect("Pick:")
            .options(["A", "B", "C"])
        let result = ms.run(mock)
        @Assert(result.size == 1)
        @Assert(result[0] == "B")
    }

    @TestCase
    func testMultiSelectMultiple() {
        let mock = InputMock().addLine("1,3")
        let ms = MultiSelect("Pick:")
            .options(["Alpha", "Beta", "Gamma"])
        let result = ms.run(mock)
        @Assert(result.size == 2)
        @Assert(result[0] == "Alpha")
        @Assert(result[1] == "Gamma")
    }

    @TestCase
    func testMultiSelectWithSpaces() {
        let mock = InputMock().addLine("1, 2, 3")
        let ms = MultiSelect("Pick:")
            .options(["X", "Y", "Z"])
        let result = ms.run(mock)
        @Assert(result.size == 3)
    }

    @TestCase
    func testMultiSelectInvalidSkipped() {
        let mock = InputMock().addLine("1,99,2")
        let ms = MultiSelect("Pick:")
            .options(["A", "B"])
        let result = ms.run(mock)
        @Assert(result.size == 2)
        @Assert(result[0] == "A")
        @Assert(result[1] == "B")
    }

    @TestCase
    func testMultiSelectEOF() {
        let mock = InputMock()
        let ms = MultiSelect("Pick:").options(["A"])
        let result = ms.run(mock)
        @Assert(result.size == 0)
    }

    @TestCase
    func testMultiSelectRender() {
        let ms = MultiSelect("Select features:")
            .options(["TypeCheck", "Lint", "Format"])
        let text = ms.render()
        @Assert(text.contains("Select features:"))
        @Assert(text.contains("1. TypeCheck"))
        @Assert(text.contains("comma-separated"))
    }
}

// ===============================================================
// 交互组件与 mockRun 集成测试
// ===============================================================
@Test
class WidgetIntegrationTest {
    @TestCase
    func testSpinnerInAction() {
        let log = ArrayList<String>()
        let app = App("tool")
            .command(
                Command("build")
                    .action({ ctx =>
                        let s = Spinner().message("Compiling...")
                        log.add(s.render())
                        s.tick()
                        log.add(s.render())
                        s.finish(message: "Build complete")
                        log.add(s.render())
                        0
                    })
            )

        let result = app.mockRun(["build"])
        @Assert(result.exitCode == 0)
        @Assert(log.size == 3)
        @Assert(log[0].contains("Compiling..."))
        @Assert(log[2].contains("✓"))
        @Assert(log[2].contains("Build complete"))
    }

    @TestCase
    func testProgressBarInAction() {
        let log = ArrayList<String>()
        let app = App("tool")
            .command(
                Command("download")
                    .action({ ctx =>
                        let bar = ProgressBar(3).width(10)
                        bar.advance()
                        bar.advance()
                        bar.advance()
                        log.add(bar.render())
                        if (bar.isComplete()) { 0 } else { 1 }
                    })
            )

        let result = app.mockRun(["download"])
        @Assert(result.exitCode == 0)
        @Assert(log[0].contains("100%"))
    }

    @TestCase
    func testConfirmInAction() {
        let mock = InputMock().addLine("yes")
        let log = ArrayList<String>()

        let app = App("tool")
            .command(
                Command("delete")
                    .action({ ctx =>
                        let confirm = Confirm("Are you sure?")
                        if (confirm.run(mock)) {
                            log.add("deleted")
                            0
                        } else {
                            log.add("cancelled")
                            1
                        }
                    })
            )

        let result = app.mockRun(["delete"])
        @Assert(result.exitCode == 0)
        @Assert(log[0] == "deleted")
    }

    @TestCase
    func testSelectInAction() {
        let mock = InputMock().addLine("2")
        let log = ArrayList<String>()

        let app = App("tool")
            .command(
                Command("deploy")
                    .action({ ctx =>
                        let sel = Select("Environment:")
                            .options(["dev", "staging", "prod"])
                        match (sel.run(mock)) {
                            case Some(env) => log.add(env)
                            case None => ()
                        }
                        0
                    })
            )

        let result = app.mockRun(["deploy"])
        @Assert(result.exitCode == 0)
        @Assert(log[0] == "staging")
    }
}
